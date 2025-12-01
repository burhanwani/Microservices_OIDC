# LocalStack + Keycloak + Istio Demo

This project demonstrates how to use **Keycloak** as an OIDC Identity Provider for **LocalStack** (simulating AWS IAM and KMS) within a **Kubernetes** cluster with **Istio Service Mesh**.

It includes a **Python Flask Server** that implements:
-   **Istio mTLS**: Automatic mutual TLS between services (Server <-> Redis).
-   **KMS Envelope Encryption**: for data storage.
-   **Read-Through Caching**: with Redis and Postgres.
-   **IAM Authentication**: via Keycloak.

## Prerequisites

- [Kubernetes Cluster](https://kubernetes.io/) (Kind, Minikube, Docker Desktop)
- [Istio](https://istio.io/) (`istioctl` installed and initialized)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Docker](https://www.docker.com/) (to build server image)

## Setup

### 1. Build Server Image
Load the server image into your K8s cluster (example for Kind):
```bash
docker build -t server:latest ./server
# If using Kind:
# kind load docker-image server:latest
```

### 2. Deploy to Kubernetes
Apply the manifests. The namespace `cloud-demo` has `istio-injection=enabled`.
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/
```

### 3. Configure Keycloak (Manual Setup)
1.  **Port Forward**: `kubectl -n cloud-demo port-forward svc/keycloak 8080:8080`
2.  **Access**: [http://localhost:8080](http://localhost:8080) (admin/admin).
3.  **Create Realm**: `my-cloud`.
4.  **Create Client**: `my-microservice` (OpenID Connect, Client Auth ON, Service Accounts ON, Direct Access Grants ON).
    -   **Important**: Copy the Client Secret. If it is NOT `helloWorld`, you must update the `server` Deployment env var in `k8s/server.yaml` and re-apply.
5.  **Create User**: `user1` (Email: `user1@example.com`, Email Verified: ON, Password: `password123` Permanent).

### 4. Initialize LocalStack
The `localstack` deployment automatically runs `init-aws.sh` on startup to register Keycloak as an OIDC provider and create the KMS key.

## Usage

### Backend Server API
1.  **Port Forward**: `kubectl -n cloud-demo port-forward svc/server 5000:5000`

#### Store Data
```bash
curl -X POST -H "Content-Type: application/json" \
     -d '{"key": "secret1", "payload": "This is my secret data"}' \
     http://localhost:5000/store
```

#### Retrieve Data
```bash
curl http://localhost:5000/retrieve/secret1
```

## Architecture

![Architecture Diagram](images/architecture.png)

### Components
-   **Server**: Flask App. Authenticates with Keycloak. Calls KMS. Connects to Redis (plaintext -> Envoy -> mTLS).
-   **Redis**: Standard Redis. Envoy sidecar handles mTLS termination.
-   **Database**: Postgres.
-   **Keycloak**: OIDC Provider.
-   **LocalStack**: Simulates AWS STS and KMS.

### Security Flow (Istio)
1.  **Transport**: Server sends plaintext request to `redis:6379`.
2.  **Encryption**: Server's Envoy proxy intercepts, encrypts (mTLS), and sends to Redis's Envoy.
3.  **Decryption**: Redis's Envoy decrypts and passes plaintext to Redis.
