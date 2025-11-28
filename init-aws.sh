#!/bin/bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# 1. Register Keycloak as an OIDC Provider in LocalStack IAM
# Note: The URL must be how LOCALSTACK sees Keycloak (internal docker DNS)
awslocal iam create-open-id-connect-provider \
    --url http://localhost:8080/realms/my-cloud \
    --client-id-list my-microservice \
    --thumbprint-list 9e99a48a9960b14926bb7f3b02e22da2b0ab7280 
    # (Thumbprint is required by API but ignored by LocalStack validation)

# 2. Create an IAM Role for the App
# This Trust Policy says: "Allow anyone with a valid token from Keycloak (aud=my-microservice) to assume this role"
cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::000000000000:oidc-provider/localhost:8080/realms/my-cloud"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "localhost:8080/realms/my-cloud:aud": "my-microservice"
        }
      }
    }
  ]
}
EOF

awslocal iam create-role --role-name MyAppRole --assume-role-policy-document file://trust-policy.json

# 3. Create a KMS Key
KEY_ID=$(awslocal kms create-key --query 'KeyMetadata.KeyId' --output text)
echo "Created KMS Key: $KEY_ID"

awslocal kms create-alias --alias-name alias/my-key --target-key-id $KEY_ID
echo "Created Alias: alias/my-key"

# 4. Give the Role permission to use the Key
# (Simple policy: Allow the role to do everything on this key)
awslocal kms put-key-policy \
    --key-id $KEY_ID \
    --policy-name default \
    --policy "{\"Version\": \"2012-10-17\",\"Statement\": [{\"Effect\": \"Allow\",\"Principal\": {\"AWS\": \"arn:aws:iam::000000000000:role/MyAppRole\"},\"Action\": \"kms:*\",\"Resource\": \"*\"}]}"

echo "Setup Complete. Key ID: $KEY_ID"