# Kubernetes Cluster on Azure VMs

Complete Kubernetes cluster infrastructure on Azure Virtual Machines with persistent storage, load balancing, and blob storage integration for development and preview environments.

## Overview

This project provides Infrastructure as Code (Terraform) and automation scripts to deploy a production-ready Kubernetes cluster on Azure VMs with:

- 1x Control Plane node (Standard_D2s_v3)
- 2x Worker nodes (Standard_E2s_v3)
- Azure Load Balancer for external access
- Azure Disk CSI Driver for persistent storage
- Azure Blob Storage integration
- Pre-configured applications (MongoDB, Redis, Jetty)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Azure Resource Group                    │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Azure Load Balancer (Public IP)          │   │
│  └──────────────────────────────────────────────────────┘   │
│                            │                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Virtual Network (10.0.0.0/16)          │    │
│  │  ┌──────────────────────────────────────────────┐   │    │
│  │  │         Subnet (10.0.1.0/24)                 │   │    │
│  │  │                                               │   │    │
│  │  │  ┌──────────────┐  ┌──────────┐ ┌──────────┐│   │    │
│  │  │  │ Control Plane│  │ Worker-1 │ │ Worker-2 ││   │    │
│  │  │  │  (Public IP) │  │(Pub. IP) │ │(Pub. IP) ││   │    │
│  │  │  └──────────────┘  └──────────┘ └──────────┘│   │    │
│  │  └──────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌──────────────────┐     ┌─────────────────────────────┐   │
│  │  Storage Account │     │   Managed Disks (Premium)   │   │
│  │  (Blob Storage)  │     │   - MongoDB (10GB)          │   │
│  └──────────────────┘     │   - Redis (5GB)             │   │
│                            │   - Jetty (5GB)             │   │
│                            └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

Before you begin, ensure you have the following installed:

1. **Azure CLI** (v2.30.0 or later)
   ```bash
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   ```

2. **Terraform** (v1.0 or later)
   ```bash
   wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install terraform
   ```

3. **kubectl** (v1.28 or compatible)
   ```bash
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   ```

4. **SSH Key Pair**
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
   ```

5. **Azure Account** with appropriate permissions to create:
   - Resource Groups
   - Virtual Networks
   - Virtual Machines
   - Load Balancers
   - Storage Accounts
   - Role Assignments

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd kubernetes-azure-cluster
```

### 2. Authenticate with Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 3. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific values:

```hcl
resource_group_name = "k8s-dev-rg"
location            = "eastus"
ssh_public_key_path = "~/.ssh/id_rsa.pub"
admin_username      = "azureuser"
```

### 4. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply -auto-approve
```

**Note:** Deployment takes approximately 10-15 minutes. VMs will automatically reboot after cloud-init completes.

### 5. Save Terraform Outputs

```bash
# Save important outputs
terraform output > ../outputs.txt

# Get control plane IP
CONTROL_PLANE_IP=$(terraform output -raw control_plane_public_ip)
echo "Control Plane IP: $CONTROL_PLANE_IP"

# Get storage account details
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)
STORAGE_KEY=$(terraform output -raw storage_account_primary_key)
```

### 6. Wait for VMs to Initialize

The cloud-init process takes 5-10 minutes. Wait for VMs to reboot and come back online:

```bash
# Check control plane
ssh azureuser@$CONTROL_PLANE_IP "systemctl status kubelet"
```

### 7. Initialize Kubernetes Control Plane

```bash
# Copy setup script to control plane
scp ../scripts/setup-control-plane.sh azureuser@$CONTROL_PLANE_IP:~

# SSH to control plane
ssh azureuser@$CONTROL_PLANE_IP

# Run setup script
sudo ./setup-control-plane.sh
```

**Important:** Save the `kubeadm join` command output! You'll need it for worker nodes.

### 8. Join Worker Nodes

For each worker node:

```bash
# Get worker IPs from Terraform
WORKER_IPS=$(cd terraform && terraform output -json worker_public_ips | jq -r '.[]')

# Copy setup script
for IP in $WORKER_IPS; do
  scp ../scripts/setup-worker.sh azureuser@$IP:~
done

# SSH to each worker and join cluster (replace with actual join command)
ssh azureuser@<WORKER_IP>
sudo ./setup-worker.sh 'kubeadm join <CONTROL_PLANE_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>'
```

### 9. Configure kubectl on Your Local Machine

```bash
# From control plane, copy kubeconfig
scp azureuser@$CONTROL_PLANE_IP:~/.kube/config ~/.kube/config-azure-k8s

# Set KUBECONFIG environment variable
export KUBECONFIG=~/.kube/config-azure-k8s

# Verify cluster
kubectl get nodes
```

Expected output:
```
NAME                        STATUS   ROLES           AGE   VERSION
k8s-dev-rg-control-plane    Ready    control-plane   10m   v1.28.0
k8s-dev-rg-worker-1         Ready    <none>          5m    v1.28.0
k8s-dev-rg-worker-2         Ready    <none>          5m    v1.28.0
```

### 10. Install Azure CSI Drivers

```bash
# Copy and run CSI driver installation script
scp ../scripts/install-csi-drivers.sh azureuser@$CONTROL_PLANE_IP:~
ssh azureuser@$CONTROL_PLANE_IP

./install-csi-drivers.sh
```

### 11. Configure Storage Classes

```bash
# Copy Kubernetes manifests to control plane
scp -r ../kubernetes azureuser@$CONTROL_PLANE_IP:~

# Apply storage classes
kubectl apply -f ~/kubernetes/storage-class.yaml

# Verify storage classes
kubectl get storageclass
```

### 12. Configure Azure Blob Storage Access

```bash
# Create secret with storage credentials
kubectl create secret generic azure-storage-secret \
  --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT \
  --from-literal=azurestorageaccountkey=$STORAGE_KEY

# Create ConfigMap
kubectl create configmap azure-storage-config \
  --from-literal=storage_account_name=$STORAGE_ACCOUNT \
  --from-literal=storage_container_name=kubernetes-data
```

### 13. Deploy Applications

```bash
# Deploy MongoDB
kubectl apply -f ~/kubernetes/mongodb-statefulset.yaml

# Deploy Redis
kubectl apply -f ~/kubernetes/redis-statefulset.yaml

# Deploy Jetty
kubectl apply -f ~/kubernetes/jetty-deployment.yaml

# Check deployments
kubectl get pods
kubectl get pvc
kubectl get svc
```

### 14. Access Applications

```bash
# Get Jetty LoadBalancer IP
kubectl get svc jetty

# Wait for EXTERNAL-IP to be assigned (may take 2-5 minutes)
# Access via: http://<EXTERNAL-IP>
```

## Detailed Configuration

### Storage Classes

Three storage classes are configured:

1. **azure-disk-standard** (default)
   - Type: StandardSSD_LRS
   - Use for: Development workloads
   - Cost: ~$0.05/GB/month

2. **azure-disk-premium**
   - Type: Premium_LRS
   - Use for: Production workloads requiring high IOPS
   - Cost: ~$0.15/GB/month

3. **azure-blob**
   - Type: Azure Blob Storage via CSI
   - Use for: Large files, backups
   - Cost: ~$0.02/GB/month

### Application Details

#### MongoDB
- **Image:** mongo:6.0
- **Storage:** 10GB persistent volume
- **Resources:** 512Mi-1Gi RAM, 250m-500m CPU
- **Access:** `mongodb.default.svc.cluster.local:27017`
- **Credentials:** admin/changeme (change in production!)

#### Redis
- **Image:** redis:7.0-alpine
- **Storage:** 5GB persistent volume (AOF enabled)
- **Resources:** 256Mi-512Mi RAM, 100m-250m CPU
- **Access:** `redis.default.svc.cluster.local:6379`
- **Password:** changeme (change in production!)

#### Jetty
- **Image:** jetty:11-jre11
- **Storage:** 5GB persistent volume
- **Resources:** 256Mi-512Mi RAM, 200m-500m CPU
- **Access:** Via LoadBalancer external IP on port 80
- **Replicas:** 2

### Azure Blob Storage Integration

Applications can connect to Azure Blob Storage using:

**1. Using Managed Identity (Recommended)**
```python
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

credential = DefaultAzureCredential()
blob_service_client = BlobServiceClient(
    account_url=f"https://{storage_account_name}.blob.core.windows.net",
    credential=credential
)
```

**2. Using Connection String**
```python
from azure.storage.blob import BlobServiceClient

connection_string = os.environ.get("AZURE_STORAGE_CONNECTION_STRING")
blob_service_client = BlobServiceClient.from_connection_string(connection_string)
```

**3. Mount as Volume (via CSI Driver)**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: blob-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: azure-blob
  resources:
    requests:
      storage: 100Gi
```

## Maintenance

### Scaling Worker Nodes

```bash
cd terraform
# Edit terraform.tfvars
# worker_count = 3

terraform apply
# Then SSH to new worker and run setup-worker.sh
```

### Backup MongoDB

```bash
kubectl exec -it mongodb-0 -- mongodump --archive=/tmp/backup.archive
kubectl cp mongodb-0:/tmp/backup.archive ./backup.archive
```

### View Logs

```bash
# Application logs
kubectl logs -f deployment/jetty
kubectl logs -f statefulset/mongodb
kubectl logs -f statefulset/redis

# Kubelet logs
ssh azureuser@<node-ip>
sudo journalctl -u kubelet -f
```

### Upgrade Kubernetes

```bash
# On control plane
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubeadm=1.29.0-00 kubelet=1.29.0-00 kubectl=1.29.0-00
sudo apt-mark hold kubeadm kubelet kubectl

sudo kubeadm upgrade apply v1.29.0
sudo systemctl restart kubelet

# Repeat on worker nodes
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name>

# Check node status
kubectl describe node <node-name>

# Check CSI driver
kubectl get pods -n kube-system | grep csi
```

### PVC Stuck in Pending

```bash
# Check PVC events
kubectl describe pvc <pvc-name>

# Check storage class
kubectl get storageclass

# Check CSI driver logs
kubectl logs -n kube-system -l app=csi-azuredisk-controller
```

### Cannot SSH to VMs

```bash
# Check NSG rules
az network nsg rule list --resource-group k8s-dev-rg --nsg-name k8s-dev-rg-nsg -o table

# Check public IP
az network public-ip list --resource-group k8s-dev-rg -o table

# Check VM status
az vm list --resource-group k8s-dev-rg --show-details -o table
```

### LoadBalancer Not Getting External IP

```bash
# Check service
kubectl describe svc jetty

# Check Azure Load Balancer
az network lb list --resource-group k8s-dev-rg -o table

# Check backend pool
az network lb address-pool list --resource-group k8s-dev-rg --lb-name k8s-dev-rg-lb -o table
```

### Cloud-Init Failed

```bash
# SSH to VM
ssh azureuser@<vm-ip>

# Check cloud-init logs
sudo cat /var/log/cloud-init.log
sudo cat /var/log/cloud-init-output.log

# Check if services are running
systemctl status containerd
systemctl status kubelet
```

## Cost Optimization

### Estimated Monthly Cost (US East)
- 3x VMs (1x D2s_v3, 2x E2s_v3): ~$150-200
- Storage (20GB Premium SSD): ~$3
- Load Balancer: ~$20
- Blob Storage (minimal): ~$1
- Bandwidth: ~$5-20

**Total: ~$180-250/month**

### Cost-Saving Tips

1. **Stop VMs when not in use**
   ```bash
   az vm deallocate --resource-group k8s-dev-rg --name <vm-name>
   az vm start --resource-group k8s-dev-rg --name <vm-name>
   ```

2. **Use B-series burstable VMs for dev** (Edit terraform.tfvars)
   ```hcl
   control_plane_vm_size = "Standard_B2s"
   worker_vm_size = "Standard_B2ms"
   ```

3. **Use Azure Dev/Test Subscription** (40% discount on VMs)

4. **Delete unused persistent volumes**
   ```bash
   kubectl delete pvc <unused-pvc>
   ```

## Security Considerations

⚠️ **Important Security Notes for Production:**

1. **Change default passwords** in MongoDB and Redis
2. **Restrict NSG rules** to specific IP ranges
3. **Enable Azure RBAC** for Kubernetes
4. **Use Azure Key Vault** for secrets
5. **Enable Pod Security Standards**
6. **Configure Network Policies**
7. **Enable audit logging**
8. **Regular security updates** on VMs
9. **Use Private Link** for storage accounts
10. **Implement backup strategy**

## Cleanup

To destroy all resources:

```bash
# From terraform directory
terraform destroy -auto-approve
```

This will delete:
- All VMs and disks
- Load Balancer and Public IPs
- Virtual Network and Subnets
- Storage Account (and data!)
- Resource Group

⚠️ **Warning:** This is irreversible! Backup any important data first.

## Support and Contributing

For issues, questions, or contributions:
- Open an issue in the repository
- Submit a pull request
- Check documentation at `docs/`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Azure Kubernetes Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [Azure Disk CSI Driver](https://github.com/kubernetes-sigs/azuredisk-csi-driver)
- [Azure Blob CSI Driver](https://github.com/kubernetes-sigs/blob-csi-driver)
- [kubeadm Documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
