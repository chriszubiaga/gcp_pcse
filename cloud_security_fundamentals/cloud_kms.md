# Cloud Key Management Service (KMS)

## Overview
- Cryptographic key management service on Google Cloud
- Enables encryption and decryption of data
- Manages encryption keys securely
- Integrates with other Google Cloud services

## Key Components

### 1. KeyRing
- Container for CryptoKeys
- Regional resource
- Organizes keys by purpose or environment
- IAM permissions can be set at KeyRing level

### 2. CryptoKey
- Represents a cryptographic key
- Can be used for encryption/decryption
- Supports key rotation
- Can be enabled/disabled
- Versioned resource

## Implementation Steps

### 1. Enable Cloud KMS
```bash
# Enable Cloud KMS API
gcloud services enable cloudkms.googleapis.com
```

### 2. Create KeyRing and CryptoKey
```bash
# Set variables
KEYRING_NAME="test"
CRYPTOKEY_NAME="qwiklab"

# Create KeyRing
gcloud kms keyrings create $KEYRING_NAME \
  --location global

# Create CryptoKey
gcloud kms keys create $CRYPTOKEY_NAME \
  --keyring $KEYRING_NAME \
  --location global \
  --purpose encryption
```

### 3. Encrypt Data
```bash
# Encrypt a file
PLAINTEXT=$(cat file.txt | base64 -w0)
curl -v "https://cloudkms.googleapis.com/v1/projects/$DEVSHELL_PROJECT_ID/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:encrypt" \
  -d "{\"plaintext\":\"$PLAINTEXT\"}" \
  -H "Authorization:Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type:application/json" \
  | jq .ciphertext -r > file.txt.encrypted
```

### 4. Configure IAM Permissions
```bash
# Get current user email
USER_EMAIL=$(gcloud auth list --limit=1 2>/dev/null | grep '@' | awk '{print $2}')

# Grant KMS admin role
gcloud kms keyrings add-iam-policy-binding $KEYRING_NAME \
  --location global \
  --member user:$USER_EMAIL \
  --role roles/cloudkms.admin

# Grant encryption/decryption role
gcloud kms keyrings add-iam-policy-binding $KEYRING_NAME \
  --location global \
  --member user:$USER_EMAIL \
  --role roles/cloudkms.cryptoKeyEncrypterDecrypter
```

### 5. Batch Encryption
```bash
# Encrypt multiple files
MYDIR=directory_name
FILES=$(find $MYDIR -type f -not -name "*.encrypted")

for file in $FILES; do
  PLAINTEXT=$(cat $file | base64 -w0)
  curl -v "https://cloudkms.googleapis.com/v1/projects/$DEVSHELL_PROJECT_ID/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:encrypt" \
    -d "{\"plaintext\":\"$PLAINTEXT\"}" \
    -H "Authorization:Bearer $(gcloud auth application-default print-access-token)" \
    -H "Content-Type:application/json" \
    | jq .ciphertext -r > $file.encrypted
done
```

## IAM Roles and Permissions

### 1. Key Management Roles
- `roles/cloudkms.admin`: Manage KMS resources
- `roles/cloudkms.cryptoKeyEncrypterDecrypter`: Encrypt/decrypt data
- `roles/cloudkms.cryptoKeyEncrypter`: Only encrypt data
- `roles/cloudkms.cryptoKeyDecrypter`: Only decrypt data

### 2. Permission Inheritance
- Project-level permissions apply to all KeyRings
- KeyRing-level permissions apply to all CryptoKeys
- CryptoKey-level permissions apply to specific keys

## Best Practices

### 1. Key Management
- Use separate KeyRings for different environments
- Implement key rotation policies
- Monitor key usage
- Regular security audits

### 2. Security
- Follow principle of least privilege
- Use appropriate IAM roles
- Monitor access patterns
- Regular key rotation

### 3. Implementation
- Use proper error handling
- Implement key versioning
- Monitor encryption operations
- Regular backups

## Important Considerations

### 1. Security
- Protect key access
- Monitor key usage
- Regular security reviews
- Proper IAM configuration

### 2. Performance
- Encryption adds latency
- Batch operations when possible
- Monitor API quotas
- Cache when appropriate

### 3. Maintenance
- Regular key rotation
- Monitor key versions
- Update IAM policies
- Regular security audits

## Common Use Cases
1. Data encryption at rest
2. Secure key storage
3. Application secrets management
4. Database encryption
5. File encryption
6. API key management
7. Service account key management 