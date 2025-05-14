# Identity-Aware Proxy (IAP)

## Overview
- Google Cloud service that intercepts web requests to applications
- Authenticates users using Google Identity Service
- Provides user identity information to applications
- Enables access control without application-level authentication code

## Key Features
1. **Authentication**
   - Intercepts web requests
   - Authenticates users via Google Identity Service
   - Controls access based on user authorization

2. **User Identity Information**
   - Provides user data to applications
   - Includes email and unique ID
   - Can be cryptographically verified

3. **Access Control**
   - Restricts access to authorized users
   - No application code changes needed for basic access control
   - Can be enabled/disabled at service level

## Implementation Steps

### 1. Deploy Application
```bash
# Download application code
gsutil cp gs://spls/gsp499/user-authentication-with-iap.zip .
unzip user-authentication-with-iap.zip
cd user-authentication-with-iap

# Deploy to App Engine
cd 1-HelloWorld
gcloud app deploy
```

### 2. Enable IAP
1. Navigate to Security > Identity-Aware Proxy
2. Find App Engine app
3. Click IAP toggle switch to enable
4. Configure access:
   - Add authorized users/groups
   - Set access policies

### 3. Access User Identity
```python
# Example code to access user identity
def get_user_info():
    # Get user email from IAP header
    user_email = request.headers.get('X-Goog-Authenticated-User-Email')
    # Get user ID from IAP header
    user_id = request.headers.get('X-Goog-Authenticated-User-ID')
    return user_email, user_id
```

### 4. Cryptographic Verification
```python
# Example code for cryptographic verification
def verify_user():
    # Get JWT assertion from IAP
    assertion = request.headers.get('X-Goog-IAP-JWT-Assertion')
    if assertion is None:
        return None, None
    
    # Verify and decode JWT
    info = jwt.decode(
        assertion,
        keys(),
        algorithms=['ES256'],
        audience=audience()
    )
    
    # Return verified user info
    return info['email'], info['sub']
```

## Security Headers
1. **X-Goog-Authenticated-User-Email**
   - Contains user's email address
   - Format: `accounts.google.com:user@example.com`

2. **X-Goog-Authenticated-User-ID**
   - Contains user's unique ID
   - Format: `accounts.google.com:123456789`

3. **X-Goog-IAP-JWT-Assertion**
   - Contains cryptographically signed user data
   - Used for verification
   - Cannot be spoofed

## Best Practices

### 1. Security
- Always verify user identity when needed
- Use cryptographic verification for sensitive data
- Regularly review access policies
- Monitor access patterns

### 2. Implementation
- Use proper error handling
- Implement graceful fallbacks
- Cache verification results
- Handle IAP disabled scenarios

### 3. Access Control
- Follow principle of least privilege
- Regular access reviews
- Document access policies
- Monitor access logs

## Important Considerations

### 1. Security Risks
- IAP can be disabled
- Headers can be spoofed if IAP is off
- Need cryptographic verification for sensitive data
- Regular security audits needed

### 2. Performance
- JWT verification adds latency
- Cache verification results when possible
- Monitor response times
- Optimize verification process

### 3. Maintenance
- Keep IAP configuration updated
- Monitor for changes in Google's keys
- Regular security reviews
- Update access policies as needed

## Common Use Cases
1. Internal applications
2. Partner access portals
3. Customer-facing applications
4. Administrative interfaces
5. API endpoints
6. Microservices
7. Legacy application modernization 