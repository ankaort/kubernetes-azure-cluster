# Quick Start Guide

Get your Kubernetes cluster running in 30 minutes!

## Prerequisites Checklist

- [ ] Azure account with active subscription
- [ ] Azure CLI installed and authenticated
- [ ] Terraform installed (v1.0+)
- [ ] kubectl installed (v1.28+)
- [ ] SSH key pair generated
- [ ] 30 minutes of time

## Step-by-Step Setup

### 1. Authentication (2 minutes)

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "<your-subscription-id>"

# Verify
az account show
```

### 2. Clone and Configure (3 minutes)

```bash
# Clone repository
git clone <repository-url>
cd kubernetes-azure-cluster/terraform

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Minimum required changes in `terraform.tfvars`:**
```hcl
resource_group_name = "k8s-dev-rg"          # Your resource group name
location            = "eastus"               # Your preferred region
ssh_public_key_path = "~/.ssh/id_rsa.pub"  # Your SSH public key
```

### 3. Deploy Infrastructure (15 minutes)

```bash
# Initialize Terraform
terraform init

# Plan and review
terraform plan

# Apply (takes ~10-15 minutes)
terraform apply -auto-approve

# Save outputs
terraform output > ../outputs.txt
```

☕ **Grab a coffee!** VMs are being created and cloud-init is installing packages.

### 4. Wait for VMs (5-10 minutes)

VMs will automatically reboot after cloud-init completes.

```bash
# Get control plane IP
CONTROL_PLANE_IP=$(terraform output -raw control_plane_public_ip)

# Wait for VM to be ready (may take 5-10 minutes)
until ssh -o ConnectTimeout=5 azureuser@$CONTROL_PLANE_IP "systemctl is-active kubelet"; do
    echo "Waiting for control plane to be ready..."
    sleep 30
done
```

### 5. Initialize Kubernetes (5 minutes)

```bash
# Copy and run setup script
scp ../scripts/setup-control-plane.sh azureuser@$CONTROL_PLANE_IP:~
ssh azureuser@$CONTROL_PLANE_IP "sudo ./setup-control-plane.sh"
```

**⚠️ IMPORTANT:** Copy the `kubeadm join` command from the output!

### 6. Join Worker Nodes (3 minutes)

```bash
# Get worker IPs
WORKER1=$(terraform output -json worker_public_ips | jq -r '.[0]')
WORKER2=$(terraform output -json worker_public_ips | jq -r '.[1]')

# Copy setup script
scp ../scripts/setup-worker.sh azureuser@$WORKER1:~
scp ../scripts/setup-worker.sh azureuser@$WORKER2:~

# Join cluster (replace with your actual join command)
JOIN_CMD='kubeadm join <IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>'

ssh azureuser@$WORKER1 "sudo ./setup-worker.sh '$JOIN_CMD'"
ssh azureuser@$WORKER2 "sudo ./setup-worker.sh '$JOIN_CMD'"
```

### 7. Configure Local Access (2 minutes)

```bash
# Copy kubeconfig
scp azureuser@$CONTROL_PLANE_IP:~/.kube/config ~/.kube/config-azure-k8s

# Use config
export KUBECONFIG=~/.kube/config-azure-k8s

# Verify cluster
kubectl get nodes
```

Expected output:
```
NAME                       STATUS   ROLES           AGE   VERSION
k8s-dev-rg-control-plane   Ready    control-plane   5m    v1.28.0
k8s-dev-rg-worker-1        Ready    <none>          2m    v1.28.0
k8s-dev-rg-worker-2        Ready    <none>          2m    v1.28.0
```

### 8. Install CSI Drivers (3 minutes)

```bash
# Copy scripts and manifests
scp ../scripts/install-csi-drivers.sh azureuser@$CONTROL_PLANE_IP:~
scp -r ../kubernetes azureuser@$CONTROL_PLANE_IP:~

# Install CSI drivers
ssh azureuser@$CONTROL_PLANE_IP "./install-csi-drivers.sh"

# Configure storage classes
kubectl apply -f ~/kubernetes/storage-class.yaml
```

### 9. Deploy Applications (2 minutes)

```bash
# Deploy all applications
kubectl apply -f https://raw.githubusercontent.com/<your-repo>/kubernetes/mongodb-statefulset.yaml
kubectl apply -f https://raw.githubusercontent.com/<your-repo>/kubernetes/redis-statefulset.yaml
kubectl apply -f https://raw.githubusercontent.com/<your-repo>/kubernetes/jetty-deployment.yaml

# Or from local files
cd ../kubernetes
kubectl apply -f mongodb-statefulset.yaml
kubectl apply -f redis-statefulset.yaml
kubectl apply -f jetty-deployment.yaml
```

### 10. Verify Deployment (2 minutes)

```bash
# Check pods
kubectl get pods --watch

# Check PVCs
kubectl get pvc

# Check services
kubectl get svc

# Wait for Jetty LoadBalancer IP (takes 2-5 minutes)
kubectl get svc jetty --watch
```

## Quick Validation

### Test MongoDB

```bash
kubectl exec -it mongodb-0 -- mongosh --eval "db.version()"
```

### Test Redis

```bash
kubectl run -it --rm redis-test --image=redis:7.0-alpine --restart=Never -- redis-cli -h redis.default.svc.cluster.local -a changeme ping
```

### Test Jetty

```bash
JETTY_IP=$(kubectl get svc jetty -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$JETTY_IP
```

## What's Next?

✅ Your cluster is ready! Now you can:

1. **Deploy your applications**
   ```bash
   kubectl apply -f your-app.yaml
   ```

2. **Configure blob storage access**
   ```bash
   STORAGE_ACCOUNT=$(cd terraform && terraform output -raw storage_account_name)
   STORAGE_KEY=$(cd terraform && terraform output -raw storage_account_primary_key)
   
   kubectl create secret generic azure-storage-secret \
     --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT \
     --from-literal=azurestorageaccountkey=$STORAGE_KEY
   ```

3. **Scale your applications**
   ```bash
   kubectl scale deployment jetty --replicas=3
   ```

4. **Monitor your cluster**
   ```bash
   kubectl top nodes
   kubectl top pods
   ```

## Common Commands

### Cluster Management

```bash
# View cluster info
kubectl cluster-info

# View all resources
kubectl get all --all-namespaces

# View events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check node status
kubectl describe node <node-name>
```

### Application Management

```bash
# View logs
kubectl logs -f <pod-name>

# Execute commands
kubectl exec -it <pod-name> -- /bin/bash

# Port forward
kubectl port-forward svc/<service-name> 8080:80

# Scale deployment
kubectl scale deployment <name> --replicas=3
```

### Troubleshooting

```bash
# Describe pod
kubectl describe pod <pod-name>

# Get pod YAML
kubectl get pod <pod-name> -o yaml

# View previous logs
kubectl logs <pod-name> --previous

# Check resource usage
kubectl top nodes
kubectl top pods
```

## Cleanup

When you're done:

```bash
cd terraform
terraform destroy -auto-approve
```

⚠️ **Warning:** This deletes everything! Backup important data first.

## Cost Estimate

Running this cluster 24/7:
- **~$180-250/month** in US East region
- **~$6-8/day** continuous usage

**Cost Saving Tips:**
- Stop VMs when not in use: `az vm deallocate`
- Use B-series VMs for dev
- Delete unused disks and snapshots

## Need Help?

- **Full Documentation**: See [README.md](../README.md)
- **Troubleshooting**: See [docs/troubleshooting.md](troubleshooting.md)
- **Architecture**: See [docs/architecture.md](architecture.md)
- **Issues**: Open a GitHub issue

---

**Congratulations! 🎉** Your Kubernetes cluster on Azure is ready to use!
