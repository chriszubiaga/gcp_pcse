# Service Accounts and Roles: Fundamentals

## Overview
- Service accounts are special Google accounts for applications/VMs, not end users
- Used for secure, managed connections to APIs and Google Cloud services
- Critical for security: enables granting access to trusted connections while rejecting malicious ones

## Types of Service Accounts

### 1. User-managed Service Accounts
- Created by users for their applications
- Default service accounts:
  - Compute Engine: `PROJECT_NUMBER-compute@developer.gserviceaccount.com`
  - App Engine: `PROJECT_ID@appspot.gserviceaccount.com`

### 2. Google-managed Service Accounts
- Created and owned by Google
- Represent different Google services
- Automatically granted IAM roles
- Example: Google APIs service account (`PROJECT_NUMBER@cloudservices.gserviceaccount.com`)

## Service Account Best Practices

### 1. Creation and Management
- Create service accounts with specific purposes
- Follow naming conventions
- Document service account usage
- Regularly review and audit service account permissions

### 2. Security Considerations
- Follow principle of least privilege
- Use service account keys only when necessary
- Rotate service account keys regularly
- Monitor service account usage
- Remove unused service account keys

### 3. Access Control
- Grant minimum required permissions
- Use predefined roles when possible
- Create custom roles for specific needs
- Regularly audit permissions

## Common Use Cases

### 1. Compute Engine Integration
- Associate service accounts with VM instances
- Enable specific API access scopes
- Control resource access through IAM roles

### 2. BigQuery Access
- Grant service accounts BigQuery roles:
  - BigQuery Data Viewer
  - BigQuery User
- Use service account credentials for API access
- Implement proper authentication in applications

## Implementation Example

### Accessing BigQuery with Service Account
1. Create service account with appropriate roles
2. Create VM instance with service account
3. Install required dependencies:
   ```bash
   sudo apt-get update
   sudo apt-get install -y git python3-pip
   pip3 install --upgrade pip
   pip3 install google-cloud-bigquery
   pip3 install pyarrow
   pip3 install pandas
   pip3 install db-dtypes
   ```
4. Use service account credentials in application:
   ```python
   from google.auth import compute_engine
   from google.cloud import bigquery
   
   credentials = compute_engine.Credentials(
       service_account_email='SERVICE_ACCOUNT_EMAIL')
   
   client = bigquery.Client(
       project='PROJECT_ID',
       credentials=credentials)
   ```

## Important Considerations
1. Service accounts are identified by unique email addresses
2. Service accounts can be granted IAM roles
3. Service accounts can be disabled or deleted
4. Service account keys should be securely stored
5. Service account permissions should be regularly audited
6. Use service accounts for automated processes and applications
7. Avoid using service accounts for manual operations

## Security Best Practices
1. Regularly rotate service account keys
2. Monitor service account usage
3. Implement least privilege access
4. Use service account key management
5. Enable audit logging for service account actions
6. Implement proper key storage and access controls
7. Regularly review and update service account permissions
