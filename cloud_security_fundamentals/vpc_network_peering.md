# VPC Network Peering

## Overview
- Enables private connectivity between VPC networks
- Works across different projects and organizations
- Useful for:
  - Organizations with multiple network administrative domains
  - Organizations needing to peer with other organizations
  - Building SaaS ecosystems in Google Cloud

## Advantages
1. **Network Latency**
   - Lower latency than public IP networking
   - Direct private connectivity

2. **Network Security**
   - Services not exposed to public internet
   - Reduced security risks
   - Private communication channel

3. **Network Cost**
   - Uses internal IPs for communication
   - Saves Google Cloud egress bandwidth costs
   - Regular network pricing still applies

## Implementation Steps

### 1. Create Custom Networks

#### Project A Setup
```bash
# Create custom network
gcloud compute networks create network-a \
  --subnet-mode=custom

# Create subnet
gcloud compute networks subnets create network-a-subnet \
  --network=network-a \
  --range=10.0.0.0/16 \
  --region=REGION

# Create VM instance
gcloud compute instances create vm-a \
  --zone=ZONE \
  --network=network-a \
  --subnet=network-a-subnet \
  --machine-type=e2-small

# Create firewall rules
gcloud compute firewall-rules create network-a-fw \
  --network=network-a \
  --allow=tcp:22,icmp
```

#### Project B Setup
```bash
# Create custom network
gcloud compute networks create network-b \
  --subnet-mode=custom

# Create subnet
gcloud compute networks subnets create network-b-subnet \
  --network=network-b \
  --range=10.8.0.0/16 \
  --region=REGION

# Create VM instance
gcloud compute instances create vm-b \
  --zone=ZONE \
  --network=network-b \
  --subnet=network-b-subnet \
  --machine-type=e2-small

# Create firewall rules
gcloud compute firewall-rules create network-b-fw \
  --network=network-b \
  --allow=tcp:22,icmp
```

### 2. Configure VPC Network Peering

#### Peer Network-A with Network-B
1. Go to VPC Network > VPC network peering
2. Click "Create connection"
3. Configure settings:
   - Name: "peer-ab"
   - Your VPC network: network-a
   - Peered VPC network: In another project
   - Project ID: [Project B ID]
   - VPC network name: network-b

#### Peer Network-B with Network-A
1. Switch to Project B
2. Go to VPC Network > VPC network peering
3. Click "Create connection"
4. Configure settings:
   - Name: "peer-ba"
   - Your VPC network: network-b
   - Peered VPC network: In another project
   - Project ID: [Project A ID]
   - VPC network name: network-a

### 3. Verify Peering Status
```bash
# List routes for Project A
gcloud compute routes list --project=PROJECT_A_ID
```

## Testing Connectivity

### 1. Get VM-A Internal IP
- Navigate to Compute Engine > VM instances
- Copy INTERNAL_IP for vm-a

### 2. Test Connection from VM-B
```bash
# SSH into vm-b
# Run ping test
ping -c 5 <INTERNAL_IP_OF_VM_A>
```

## Important Considerations

### 1. Network Configuration
- Non-overlapping IP ranges required
- Custom subnet mode needed
- Proper firewall rules essential

### 2. Security
- Private communication only
- No public internet exposure
- Proper firewall rules needed

### 3. Best Practices
- Use meaningful naming conventions
- Document peering relationships
- Monitor network traffic
- Regular security reviews

### 4. Limitations
- Maximum of 25 peering connections per network
- No transitive peering
- No overlapping IP ranges
- No route import/export between peered networks

## Common Use Cases
1. Multi-project architectures
2. Cross-organization services
3. SaaS platform development
4. Hybrid cloud connectivity
5. Microservices architecture 