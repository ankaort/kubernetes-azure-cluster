# Architecture Overview

## System Architecture

This Kubernetes cluster is designed for development and preview environments with cost optimization and simplicity in mind.

### Components

```
┌─────────────────────────────────────────────────────────────────┐
│                      Azure Cloud Platform                        │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                  Resource Group (k8s-dev-rg)                │ │
│  │                                                              │ │
│  │  ┌────────────────────────────────────────────────────┐    │ │
│  │  │       Virtual Network (10.0.0.0/16)                │    │ │
│  │  │                                                      │    │ │
│  │  │  Subnet: 10.0.1.0/24                                │    │ │
│  │  │  ┌──────────────────────────────────────────────┐  │    │ │
│  │  │  │  Network Security Group                       │  │    │ │
│  │  │  │  - SSH (22)                                   │  │    │ │
│  │  │  │  - Kubernetes API (6443)                      │  │    │ │
│  │  │  │  - NodePorts (30000-32767)                    │  │    │ │
│  │  │  │  - HTTP/HTTPS (80/443)                        │  │    │ │
│  │  │  │  - Kubelet (10250)                            │  │    │ │
│  │  │  │  - etcd (2379-2380)                           │  │    │ │
│  │  │  └──────────────────────────────────────────────┘  │    │ │
│  │  └────────────────────────────────────────────────────┘    │ │
│  │                                                              │ │
│  │  ┌────────────────────────────────────────────────────┐    │ │
│  │  │         Availability Set                           │    │ │
│  │  │                                                      │    │ │
│  │  │  ┌──────────────────┐                               │    │ │
│  │  │  │ Control Plane VM │                               │    │ │
│  │  │  │ Standard_D2s_v3  │                               │    │ │
│  │  │  │ - 2 vCPUs        │                               │    │ │
│  │  │  │ - 8 GB RAM       │                               │    │ │
│  │  │  │ - 50 GB Disk     │                               │    │ │
│  │  │  │ - Ubuntu 22.04   │                               │    │ │
│  │  │  │ - Public IP      │                               │    │ │
│  │  │  └──────────────────┘                               │    │ │
│  │  │                                                      │    │ │
│  │  │  ┌──────────────────┐  ┌──────────────────┐        │    │ │
│  │  │  │   Worker VM 1    │  │   Worker VM 2    │        │    │ │
│  │  │  │ Standard_E2s_v3  │  │ Standard_E2s_v3  │        │    │ │
│  │  │  │ - 2 vCPUs        │  │ - 2 vCPUs        │        │    │ │
│  │  │  │ - 16 GB RAM      │  │ - 16 GB RAM      │        │    │ │
│  │  │  │ - 50 GB Disk     │  │ - 50 GB Disk     │        │    │ │
│  │  │  │ - Ubuntu 22.04   │  │ - Ubuntu 22.04   │        │    │ │
│  │  │  │ - Public IP      │  │ - Public IP      │        │    │ │
│  │  │  └──────────────────┘  └──────────────────┘        │    │ │
│  │  └────────────────────────────────────────────────────┘    │ │
│  │                                                              │ │
│  │  ┌────────────────────────────────────────────────────┐    │ │
│  │  │         Azure Load Balancer (Standard SKU)         │    │ │
│  │  │  - Public IP                                        │    │ │
│  │  │  - Backend Pool: Worker VMs                        │    │ │
│  │  │  - Health Probe: TCP/80                            │    │ │
│  │  │  - Load Balancing Rule: HTTP                       │    │ │
│  │  └────────────────────────────────────────────────────┘    │ │
│  │                                                              │ │
│  │  ┌────────────────────────────────────────────────────┐    │ │
│  │  │         Storage Account                            │    │ │
│  │  │  - Standard LRS                                     │    │ │
│  │  │  - Blob Container: kubernetes-data                 │    │ │
│  │  │  - Managed Identity Access                         │    │ │
│  │  └────────────────────────────────────────────────────┘    │ │
│  │                                                              │ │
│  │  ┌────────────────────────────────────────────────────┐    │ │
│  │  │         Managed Disks (Premium SSD)                │    │ │
│  │  │  - OS Disks (3x 50GB)                              │    │ │
│  │  │  - Data Disks (Dynamic via CSI)                    │    │ │
│  │  └────────────────────────────────────────────────────┘    │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Kubernetes Architecture

### Control Plane Components

- **API Server**: Exposes Kubernetes API (port 6443)
- **etcd**: Key-value store for cluster data
- **Controller Manager**: Manages controllers (cloud provider integration)
- **Scheduler**: Assigns pods to nodes
- **Cloud Controller Manager**: Azure-specific controllers

### Node Components (All Nodes)

- **kubelet**: Node agent
- **kube-proxy**: Network proxy
- **containerd**: Container runtime
- **Calico**: Container Network Interface (CNI)
- **Azure Disk CSI Driver**: Persistent volume management
- **Azure Blob CSI Driver**: Blob storage integration

### Networking

#### Pod Network (Calico)
- **CIDR**: 10.244.0.0/16
- **Backend**: VXLAN
- **Network Policy**: Supported

#### Service Network
- **CIDR**: 10.96.0.0/12
- **Type**: ClusterIP, NodePort, LoadBalancer
- **DNS**: CoreDNS

#### External Access
1. **LoadBalancer Services**: Azure Load Balancer integration
2. **NodePort Services**: Direct node access (30000-32767)
3. **SSH**: Direct VM access

### Storage Architecture

#### Azure Disk CSI Driver
```
Application Pod
    ↓
PersistentVolumeClaim
    ↓
PersistentVolume (Dynamic)
    ↓
Azure Disk CSI Driver
    ↓
Azure Managed Disk
```

#### Storage Classes
1. **azure-disk-standard** (default)
   - SKU: StandardSSD_LRS
   - Performance: ~500 IOPS, 60 MB/s
   - Use: Development workloads

2. **azure-disk-premium**
   - SKU: Premium_LRS
   - Performance: ~120 IOPS, 25 MB/s per GB
   - Use: Production-grade workloads

3. **azure-blob**
   - Protocol: FUSE
   - Use: Shared storage, backups

### Security Architecture

#### Identity and Access
- **Managed Identity**: Enabled on all VMs
- **RBAC**: Kubernetes Role-Based Access Control
- **Azure RBAC**: Role assignments for storage access
- **Service Accounts**: Per-application service accounts

#### Network Security
- **NSG Rules**: Restrict inbound traffic
- **Private IPs**: Internal cluster communication
- **Public IPs**: SSH and API access only
- **Network Policies**: Calico network policies

#### Secrets Management
- **Kubernetes Secrets**: Base64 encoded
- **Azure Key Vault**: (Optional) External secrets
- **Storage Keys**: Managed via secrets

## Application Architecture

### MongoDB
```yaml
StatefulSet (1 replica)
├── Persistent Volume (10GB Azure Disk)
├── Service (ClusterIP, Headless)
└── Pod
    ├── Container: mongo:6.0
    ├── Port: 27017
    └── Volume: /data/db
```

### Redis
```yaml
StatefulSet (1 replica)
├── Persistent Volume (5GB Azure Disk)
├── Service (ClusterIP, Headless)
└── Pod
    ├── Container: redis:7.0-alpine
    ├── Port: 6379
    └── Volume: /data
```

### Jetty
```yaml
Deployment (2 replicas)
├── Persistent Volume (5GB Azure Disk)
├── Service (LoadBalancer)
└── Pods
    ├── Container: jetty:11-jre11
    ├── Port: 8080
    └── Volume: /var/lib/jetty/webapps
```

## Data Flow

### Application to Storage
```
Application Pod
    ↓
PVC (azure-disk-standard)
    ↓
CSI Driver
    ↓
Azure Managed Disk (attached to node)
    ↓
Local filesystem in pod
```

### Application to Blob Storage
```
Application Pod
    ↓
Managed Identity
    ↓
Azure Storage SDK
    ↓
Azure Blob Storage
```

### External User to Application
```
Internet User
    ↓
Azure Load Balancer (Public IP)
    ↓
Worker Node (Backend Pool)
    ↓
kube-proxy (iptables rules)
    ↓
Application Pod
```

## Scaling Considerations

### Vertical Scaling
- Increase VM sizes
- Increase disk sizes
- Increase application resources

### Horizontal Scaling
- Add more worker nodes
- Increase deployment replicas
- Use HorizontalPodAutoscaler

### Storage Scaling
- Increase PVC size (VolumeExpansion enabled)
- Add more disks
- Use blob storage for large data

## High Availability Notes

This setup is **NOT highly available** by design (dev environment):
- Single control plane (no redundancy)
- Single replica for stateful apps
- Same availability set (single datacenter)

For production HA:
- Multiple control plane nodes
- Multiple replicas for all apps
- Zone-redundant storage
- Cross-zone deployment
- Backup and disaster recovery
- Monitoring and alerting
