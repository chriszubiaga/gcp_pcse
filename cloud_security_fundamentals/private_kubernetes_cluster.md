# Private Kubernetes Cluster

## Overview
- Kubernetes cluster with private nodes (no public IP addresses)
- Master node inaccessible from public internet
- Nodes communicate with master using VPC peering
- Provides isolated environment for workloads
- Uses CIDR blocks for address ranges

## Implementation Steps

### 1. Basic Setup
```bash
# Set region and zone
gcloud config set compute/zone ZONE
export REGION=REGION
export ZONE=ZONE
```

### 2. Create Private Cluster
```bash
# Create private cluster with automatic subnet
gcloud beta container clusters create private-cluster \
  --enable-private-nodes \
  --master-ipv4-cidr 172.16.0.16/28 \
  --enable-ip-alias \
  --create-subnetwork ""
```

### 3. Create Custom Subnet
```bash
# Create subnet with secondary ranges
gcloud compute networks subnets create my-subnet \
  --network default \
  --range 10.0.4.0/22 \
  --enable-private-ip-google-access \
  --region=$REGION \
  --secondary-range my-svc-range=10.0.32.0/20,my-pod-range=10.4.0.0/14
```

### 4. Create Private Cluster with Custom Subnet
```bash
# Create private cluster using custom subnet
gcloud beta container clusters create private-cluster2 \
  --enable-private-nodes \
  --enable-ip-alias \
  --master-ipv4-cidr 172.16.0.32/28 \
  --subnetwork my-subnet \
  --services-secondary-range-name my-svc-range \
  --cluster-secondary-range-name my-pod-range \
  --zone=$ZONE
```

### 5. Configure Master Authorized Networks
```bash
# Get external IP of source instance
gcloud compute instances describe source-instance --zone=$ZONE | grep natIP

# Authorize external address range
gcloud container clusters update private-cluster2 \
  --enable-master-authorized-networks \
  --zone=$ZONE \
  --master-authorized-networks {natIP}/32
```

## Key Components

### 1. Network Configuration
- Primary subnet range: For node IPs
- Secondary ranges:
  - Service range: For service IPs
  - Pod range: For pod IPs
- Master CIDR range: For master node

### 2. Access Control
- Master authorized networks
- VPC peering for node-master communication
- Private Google Access enabled
- No public IPs for nodes

## Best Practices

### 1. Network Design
- Plan CIDR ranges carefully
- Avoid overlapping ranges
- Use appropriate subnet sizes
- Document network architecture

### 2. Security
- Enable private nodes
- Configure master authorized networks
- Use VPC peering
- Implement network policies

### 3. Access Management
- Control master access
- Monitor network access
- Regular security reviews
- Document access patterns

## Important Considerations

### 1. Network Requirements
- Non-overlapping CIDR ranges
- Sufficient IP space
- VPC peering support
- Private Google Access

### 2. Access Patterns
- Master access through authorized networks
- Node access through VPC
- Service access through internal load balancers
- Pod-to-pod communication within cluster

### 3. Limitations
- No direct internet access for nodes
- Requires VPC peering
- Limited to specific regions
- Additional network complexity

## Common Use Cases
1. Secure workloads
2. Compliance requirements
3. Internal applications
4. Sensitive data processing
5. Enterprise deployments
6. Multi-tenant environments
7. Regulatory compliance 