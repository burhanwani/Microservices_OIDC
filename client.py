import boto3
import requests

# CONFIG
KEYCLOAK_TOKEN_URL = "http://localhost:8080/realms/my-cloud/protocol/openid-connect/token"
LOCALSTACK_URL = "http://localhost:4566"
ROLE_ARN = "arn:aws:iam::000000000000:role/MyAppRole"
KMS_KEY_ID = "alias/my-key"

def run_real_aws_flow():
    # --- STEP 1: Get Token from Keycloak (Simulating the App Identity) ---
    print("1. Authenticating with Keycloak...")
    token_resp = requests.post(KEYCLOAK_TOKEN_URL, data={
        "grant_type": "password",
        "client_id": "my-microservice",
        "client_secret": "helloWorld",
        "username": "user1",
        "password": "password123"
    })
    print(token_resp.json())
    jwt_token = token_resp.json()['access_token']
    print("   Got JWT.")

    # --- STEP 2: Trade JWT for AWS Credentials (STS) ---
    # We use boto3 to talk to LocalStack STS
    print("2. Exchanging JWT for AWS Credentials via STS...")
    sts_client = boto3.client('sts', endpoint_url=LOCALSTACK_URL)
    
    assume_role_resp = sts_client.assume_role_with_web_identity(
        RoleArn=ROLE_ARN,
        RoleSessionName="MyMicroserviceSession",
        WebIdentityToken=jwt_token
    )
    
    creds = assume_role_resp['Credentials']
    print(f"   Got AWS AccessKey: {creds['AccessKeyId']}")

    # --- STEP 3: Use the Credentials to Encrypt Data (KMS) ---
    print("3. Encrypting data with KMS...")
    
    # Create a KMS client using the TEMPORARY credentials we just got
    kms_client = boto3.client('kms',
        endpoint_url=LOCALSTACK_URL,
        aws_access_key_id=creds['AccessKeyId'],
        aws_secret_access_key=creds['SecretAccessKey'],
        aws_session_token=creds['SessionToken'],
        region_name="us-east-1"
    )

    # Encrypt!
    response = kms_client.encrypt(
        KeyId=KMS_KEY_ID,
        Plaintext=b"This is top secret data"
    )
    
    print(f"   Success! Encrypted Blob: {response['CiphertextBlob']}")

if __name__ == "__main__":
    run_real_aws_flow()