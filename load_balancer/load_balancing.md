# Load Balancing on Compute Engine

## Overview
- Load balancing distributes traffic across multiple instances
- Two main types of load balancers:
  - Network Load Balancer (L4)
  - Application Load Balancer (L7)
- Enables high availability and scalability

## Network Load Balancer (L4)

### Overview
- Operates at the transport layer (TCP/UDP)
- For TCP/UDP traffic
- Provides high throughput
- Regional deployment
- Direct connection to backend instances

### Implementation Steps

#### 1. Create Web Server Instances
```bash
# Create first web server instance
gcloud compute instances create www1 \
  --zone=ZONE \
  --tags=network-lb-tag \
  --machine-type=e2-small \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --metadata=startup-script='#!/bin/bash
    apt-get update
    apt-get install apache2 -y
    service apache2 restart
    echo "<h3>Web Server: www1</h3>" | tee /var/www/html/index.html'

# Create second web server instance
gcloud compute instances create www2 \
  --zone=ZONE \
  --tags=network-lb-tag \
  --machine-type=e2-small \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --metadata=startup-script='#!/bin/bash
    apt-get update
    apt-get install apache2 -y
    service apache2 restart
    echo "<h3>Web Server: www2</h3>" | tee /var/www/html/index.html'

# Create third web server instance
gcloud compute instances create www3 \
  --zone=ZONE \
  --tags=network-lb-tag \
  --machine-type=e2-small \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --metadata=startup-script='#!/bin/bash
    apt-get update
    apt-get install apache2 -y
    service apache2 restart
    echo "<h3>Web Server: www3</h3>" | tee /var/www/html/index.html'
```

#### 2. Configure Firewall Rules
```bash
# Create firewall rule to allow HTTP traffic
gcloud compute firewall-rules create www-firewall-network-lb \
  --target-tags=network-lb-tag \
  --allow=tcp:80
```

#### 3. Setup Network Load Balancer
```bash
# Create a health check
gcloud compute http-health-checks create basic-check

# Create a target pool
gcloud compute target-pools create www-pool \
  --region=REGION \
  --http-health-check=basic-check

# Add instances to the target pool
gcloud compute target-pools add-instances www-pool \
  --instances=www1,www2,www3 \
  --zone=ZONE

# Create a forwarding rule
gcloud compute forwarding-rules create www-rule \
  --region=REGION \
  --ports=80 \
  --target-pool=www-pool
```

#### 4. Testing Network Load Balancer
```bash
# Get the IP address of the load balancer
gcloud compute forwarding-rules describe www-rule \
  --region=REGION \
  --format="get(IPAddress)"

# Test the load balancer (replace IP_ADDRESS with actual IP)
curl http://IP_ADDRESS/
```

## Application Load Balancer (L7)

### Overview
- Operates at the application layer (HTTP/HTTPS)
- Content-based routing
- Advanced features:
  - URL-based routing
  - Host-based routing
  - Path-based routing
- Global deployment
- SSL termination

### Implementation Steps

#### 1. Create Instance Template
```bash
# Create instance template
gcloud compute instance-templates create lb-backend-template \
  --region=REGION \
  --network=default \
  --subnet=default \
  --tags=allow-health-check \
  --machine-type=e2-medium \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --metadata=startup-script='#!/bin/bash
    apt-get update
    apt-get install apache2 -y
    a2ensite default-ssl
    a2enmod ssl
    vm_hostname="$(curl -H "Metadata-Flavor:Google" \
    http://169.254.169.254/computeMetadata/v1/instance/name)"
    echo "Page served from: $vm_hostname" | \
    tee /var/www/html/index.html
    systemctl restart apache2'
```

#### 2. Create Managed Instance Group
```bash
# Create managed instance group
gcloud compute instance-groups managed create lb-backend-group \
  --template=lb-backend-template \
  --size=2 \
  --zone=ZONE
```

#### 3. Configure Firewall Rules
```bash
# Create firewall rule for health checks
gcloud compute firewall-rules create fw-allow-health-check \
  --network=default \
  --action=allow \
  --direction=ingress \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 \
  --target-tags=allow-health-check \
  --rules=tcp:80
```

#### 4. Setup Application Load Balancer
```bash
# Create static IP address
gcloud compute addresses create lb-ipv4-1 \
  --ip-version=IPV4 \
  --global

# Create health check
gcloud compute health-checks create http http-basic-check \
  --port 80

# Create backend service
gcloud compute backend-services create web-backend-service \
  --protocol=HTTP \
  --port-name=http \
  --health-checks=http-basic-check \
  --global

# Add instance group to backend service
gcloud compute backend-services add-backend web-backend-service \
  --instance-group=lb-backend-group \
  --instance-group-zone=ZONE \
  --global

# Create URL map
gcloud compute url-maps create web-map-http \
  --default-service web-backend-service

# Create target HTTP proxy
gcloud compute target-http-proxies create http-lb-proxy \
  --url-map web-map-http

# Create forwarding rule
gcloud compute forwarding-rules create http-content-rule \
  --address=lb-ipv4-1 \
  --global \
  --target-http-proxy=http-lb-proxy \
  --ports=80
```

#### 5. Testing Application Load Balancer
```bash
# Get the IP address of the load balancer
gcloud compute addresses describe lb-ipv4-1 \
  --format="get(address)" \
  --global

# Test the load balancer (replace IP_ADDRESS with actual IP)
curl http://IP_ADDRESS/
```

## Best Practices

### 1. Instance Configuration
- Use instance templates for consistency
- Implement proper health checks
- Configure appropriate machine types
- Use managed instance groups

### 2. Security
- Configure firewall rules
- Use appropriate network tags
- Implement SSL/TLS for HTTPS
- Regular security updates

### 3. Performance
- Choose appropriate load balancer type
- Configure proper health checks
- Monitor instance health
- Implement proper session affinity

### 4. High Availability
- Deploy across multiple zones
- Use managed instance groups
- Implement proper health checks
- Configure appropriate timeouts

## Important Considerations
1. Choose appropriate load balancer type based on needs:
   - Network Load Balancer: TCP/UDP traffic, high throughput
   - Application Load Balancer: HTTP/HTTPS traffic, content-based routing
2. Configure proper health checks
3. Implement security best practices
4. Monitor performance and health
5. Regular maintenance and updates
6. Proper instance configuration
7. Appropriate network setup
