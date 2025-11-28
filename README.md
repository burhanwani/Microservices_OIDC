# LocalStack + Keycloak OIDC Demo

This project demonstrates how to use **Keycloak** as an OIDC Identity Provider for **LocalStack** (simulating AWS IAM and KMS).

## Prerequisites

- [Docker](https://www.docker.com/) & Docker Compose
- [Python 3.9+](https://www.python.org/)

## Setup

### 1. Start Services
Start the Docker containers:
```bash
docker compose up -d
```
*Wait a minute for Keycloak and LocalStack to fully initialize.*

### 2. Configure Keycloak (Manual Setup)
Since this is a fresh environment, you must configure Keycloak manually.

1.  **Access the Admin Console**:
    -   Go to [http://localhost:8080](http://localhost:8080).
    -   Click **Administration Console**.
    -   Login with **admin** / **admin**.

2.  **Create a Realm**:
    -   Hover over the **Master** realm dropdown in the top-left and click **Create Realm**.
    -   **Realm name**: `my-cloud`
    -   Click **Create**.

3.  **Create a Client**:
    -   Go to **Clients** > **Create client**.
    -   **Client type**: `OpenID Connect`.
    -   **Client ID**: `my-microservice`
    -   Click **Next**.
    -   **Capability config**:
        -   Enable **Client authentication** (this enables the client secret).
        -   Enable **Service accounts roles** (optional, but good practice).
        -   Enable **Direct access grants** (required for the python script's password flow).
    -   Click **Save**.
    -   **Get Client Secret**:
        -   Go to the **Credentials** tab.
        -   Copy the **Client secret**.
        -   Update `client.py` if the secret is not `helloWorld` (or set it to `helloWorld` if possible, though Keycloak generates random secrets by default). *Note: For this demo, it's easier to copy the generated secret and update `client.py`.*

4.  **Create a User**:
    -   Go to **Users** > **Add user**.
    -   **Username**: `user1`
    -   **Email**: `user1@example.com` (Required for IAM trust policy).
    -   **First name**: `User`
    -   **Last name**: `One`
    -   **Email verified**: **Yes** (Toggle this ON).
    -   Click **Create**.
    -   **Set Password**:
        -   Go to the **Credentials** tab.
        -   Click **Set password**.
        -   **Password**: `password123`
        -   **Temporary**: **No** (Toggle this OFF).
        -   Click **Save**.

### 3. Install Dependencies
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 4. Update Client Configuration
If your Client Secret is different from `helloWorld`, open `client.py` and update line 16:
```python
"client_secret": "YOUR_COPIED_SECRET",
```

## Usage

Run the client script:
```bash
python client.py
```

Expected output:
```text
1. Authenticating with Keycloak...
   Got JWT.
2. Exchanging JWT for AWS Credentials via STS...
   Got AWS AccessKey: ...
3. Encrypting data with KMS...
   Success! Encrypted Blob: ...
```

## Architecture
- **Keycloak**: OIDC Provider.
- **LocalStack**: Simulates AWS STS (for federation) and KMS.
- **init-aws.sh**: Automatically registers Keycloak as an OIDC provider in LocalStack and creates the necessary IAM Roles and KMS Keys on startup.
