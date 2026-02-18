# Troubleshooting Guide

## Common Issues and Solutions

### Infrastructure Issues

#### Terraform Apply Fails

**Issue**: `terraform apply` fails with authentication error

**Solution**:
```bash
# Re-authenticate with Azure
az login
az account set --subscription "<subscription-id>"

# Verify credentials
az account show
```

**Issue**: Resource already exists error

**Solution**:
```bash
# Import existing resource
terraform import azurerm_resource_group.k8s /subscriptions/<sub-id>/resourceGroups/k8s-dev-rg

# Or use different resource names in terraform.tfvars
```

**Issue**: Quota exceeded

**Solution**:
```bash
# Check quota
az vm list-usage --location eastus -o table

# Request quota increase or use different VM sizes
```

#### VM Boot Issues

**Issue**: VM doesn't respond after creation

**Solution**:
```bash
# Check VM status
az vm get-instance-view --resource-group k8s-dev-rg --name k8s-dev-rg-control-plane

# Check boot diagnostics
az vm boot-diagnostics get-boot-log --resource-group k8s-dev-rg --name k8s-dev-rg-control-plane

# Cloud-init takes 5-10 minutes - wait for reboot
```

**Issue**: Cannot SSH to VM

**Solution**:
```bash
# Verify NSG rules
az network nsg rule list --resource-group k8s-dev-rg --nsg-name k8s-dev-rg-nsg -o table

# Check public IP
az network public-ip show --resource-group k8s-dev-rg --name k8s-dev-rg-cp-pip

# Verify SSH key permissions
chmod 600 ~/.ssh/id_rsa
```

### Kubernetes Cluster Issues

#### kubeadm init Fails

**Issue**: `kubeadm init` fails with preflight check errors

**Solution**:
```bash
# Check if swap is disabled
sudo swapon --show

# Disable swap if needed
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Check if containerd is running
sudo systemctl status containerd

# Restart containerd if needed
sudo systemctl restart containerd
```

**Issue**: Port 6443 already in use

**Solution**:
```bash
# Reset kubeadm
sudo kubeadm reset

# Clean up
sudo rm -rf /etc/cni/net.d
sudo rm -rf ~/.kube/config

# Try again
sudo ./setup-control-plane.sh
```

**Issue**: etcd error during initialization

**Solution**:
```bash
# Check if etcd ports are available
sudo netstat -tulpn | grep -E '2379|2380'

# If needed, reset and clean up
sudo kubeadm reset
sudo rm -rf /var/lib/etcd
```

#### Worker Node Join Fails

**Issue**: Worker cannot join cluster

**Solution**:
```bash
# Verify connectivity to control plane
nc -zv <control-plane-ip> 6443

# Check if token is valid
ssh azureuser@<control-plane-ip>
sudo kubeadm token list

# Create new token if expired
sudo kubeadm token create --print-join-command

# Use new join command on worker
```

**Issue**: Node shows NotReady status

**Solution**:
```bash
# Check node status
kubectl describe node <node-name>

# Check kubelet logs
ssh azureuser@<node-ip>
sudo journalctl -u kubelet -f

# Check CNI
kubectl get pods -n kube-system | grep calico

# Restart kubelet if needed
sudo systemctl restart kubelet
```

### Networking Issues

#### Pods Cannot Communicate

**Issue**: Pods on different nodes cannot reach each other

**Solution**:
```bash
# Check Calico pods
kubectl get pods -n kube-system -l k8s-app=calico-node

# Check Calico node status
kubectl exec -n kube-system <calico-node-pod> -- calicoctl node status

# Verify IP forwarding
sudo sysctl net.ipv4.ip_forward

# Should be 1, if not:
sudo sysctl -w net.ipv4.ip_forward=1
```

**Issue**: Services not accessible via ClusterIP

**Solution**:
```bash
# Check kube-proxy
kubectl get pods -n kube-system | grep kube-proxy

# Check kube-proxy logs
kubectl logs -n kube-system <kube-proxy-pod>

# Verify iptables rules
ssh azureuser@<node-ip>
sudo iptables-save | grep <service-name>
```

#### LoadBalancer Service Stuck Pending

**Issue**: External IP shows `<pending>` for LoadBalancer service

**Solution**:
```bash
# Check service events
kubectl describe svc <service-name>

# Check cloud controller manager logs
kubectl logs -n kube-system <cloud-controller-manager-pod>

# Verify Azure Load Balancer
az network lb list --resource-group k8s-dev-rg -o table

# Check backend pool
az network lb address-pool list --resource-group k8s-dev-rg --lb-name k8s-dev-rg-lb -o table

# Ensure worker NICs are in backend pool
az network nic show --resource-group k8s-dev-rg --name k8s-dev-rg-worker-1-nic --query 'ipConfigurations[].loadBalancerBackendAddressPools'
```

### Storage Issues

#### CSI Driver Installation Fails

**Issue**: Azure Disk CSI driver pods not running

**Solution**:
```bash
# Check CSI driver pods
kubectl get pods -n kube-system | grep csi-azuredisk

# Check pod logs
kubectl logs -n kube-system <csi-azuredisk-controller-pod>

# Reinstall CSI driver
kubectl delete -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/install-driver.sh
./scripts/install-csi-drivers.sh
```

**Issue**: Azure Blob CSI driver fails to install

**Solution**:
```bash
# Check existing CSI drivers
kubectl get csidrivers

# Manually install blob driver
curl -skSL https://raw.githubusercontent.com/kubernetes-sigs/blob-csi-driver/master/deploy/install-driver.sh | bash -s master --

# Verify installation
kubectl get pods -n kube-system | grep csi-blob
```

#### PVC Stuck in Pending

**Issue**: PersistentVolumeClaim remains in Pending state

**Solution**:
```bash
# Check PVC events
kubectl describe pvc <pvc-name>

# Check storage class
kubectl get storageclass

# Verify CSI driver is running
kubectl get pods -n kube-system | grep csi-azuredisk

# Check disk quota
az disk list --resource-group k8s-dev-rg -o table

# Check node has capacity
kubectl describe node <node-name> | grep -A 5 "Allocated resources"
```

**Issue**: PVC bound but pod cannot mount volume

**Solution**:
```bash
# Check pod events
kubectl describe pod <pod-name>

# Common issue: Disk already attached to another node
# Solution: Delete and recreate pod to trigger reattachment

kubectl delete pod <pod-name>
# StatefulSet will recreate it
```

#### Volume Mount Permission Issues

**Issue**: Application cannot write to mounted volume

**Solution**:
```bash
# Check pod security context
kubectl get pod <pod-name> -o yaml | grep -A 10 securityContext

# Add fsGroup to pod spec
securityContext:
  fsGroup: 1000

# Or run as root (not recommended)
securityContext:
  runAsUser: 0
```

### Application Issues

#### MongoDB Pod CrashLoopBackOff

**Issue**: MongoDB pod keeps restarting

**Solution**:
```bash
# Check pod logs
kubectl logs mongodb-0

# Common issues:
# 1. Insufficient memory
kubectl describe pod mongodb-0 | grep -A 5 Limits

# 2. Volume permission issues
kubectl exec -it mongodb-0 -- ls -la /data/db

# 3. Corrupted data
kubectl delete pvc mongodb-data-mongodb-0
kubectl delete pod mongodb-0
```

#### Redis Connection Issues

**Issue**: Cannot connect to Redis

**Solution**:
```bash
# Check Redis pod status
kubectl get pod redis-0

# Test connection from another pod
kubectl run -it --rm redis-client --image=redis:7.0-alpine --restart=Never -- redis-cli -h redis.default.svc.cluster.local -a changeme ping

# Check password
kubectl get statefulset redis -o yaml | grep requirepass
```

#### Jetty Not Accessible

**Issue**: Cannot access Jetty via LoadBalancer

**Solution**:
```bash
# Check service
kubectl get svc jetty

# Wait for External-IP (takes 2-5 minutes)
kubectl get svc jetty --watch

# Check pod status
kubectl get pods -l app=jetty

# Check pod logs
kubectl logs -l app=jetty

# Test from within cluster
kubectl run -it --rm curl --image=curlimages/curl --restart=Never -- curl http://jetty.default.svc.cluster.local

# Check LoadBalancer in Azure
az network lb show --resource-group k8s-dev-rg --name k8s-dev-rg-lb
```

### Azure Blob Storage Issues

#### Cannot Access Blob Storage from Pods

**Issue**: Application cannot connect to Azure Blob Storage

**Solution**:
```bash
# Check if secret exists
kubectl get secret azure-storage-secret

# Verify secret contents (base64 decoded)
kubectl get secret azure-storage-secret -o jsonpath='{.data.azurestorageaccountname}' | base64 -d

# Test connectivity
kubectl run -it --rm azcli --image=mcr.microsoft.com/azure-cli --restart=Never -- bash
# Inside pod:
az storage blob list --account-name <storage-account> --container-name kubernetes-data --account-key <key>
```

**Issue**: Managed Identity not working

**Solution**:
```bash
# Check VM identity
az vm identity show --resource-group k8s-dev-rg --name k8s-dev-rg-control-plane

# Check role assignment
az role assignment list --assignee <principal-id> --resource-group k8s-dev-rg -o table

# Verify from VM
ssh azureuser@<vm-ip>
curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/' -H Metadata:true
```

### Performance Issues

#### High CPU Usage on Control Plane

**Solution**:
```bash
# Check CPU usage
kubectl top node

# Check which pods are consuming resources
kubectl top pods --all-namespaces

# Scale up control plane VM if needed
cd terraform
# Edit terraform.tfvars: control_plane_vm_size = "Standard_D4s_v3"
terraform apply
```

#### Slow Disk Performance

**Solution**:
```bash
# Check disk IOPS
az disk list --resource-group k8s-dev-rg -o table

# Upgrade to Premium storage class
# Edit your application YAML to use: azure-disk-premium

# Or increase disk size for more IOPS
# Supports dynamic expansion
kubectl edit pvc <pvc-name>
# Change storage: 10Gi to storage: 50Gi
```

### Debugging Commands

#### Useful kubectl Commands

```bash
# Get all resources
kubectl get all --all-namespaces

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Describe resource
kubectl describe <resource-type> <resource-name>

# Get logs
kubectl logs <pod-name>
kubectl logs <pod-name> -f  # follow
kubectl logs <pod-name> --previous  # previous instance

# Execute command in pod
kubectl exec -it <pod-name> -- /bin/bash

# Check resource usage
kubectl top nodes
kubectl top pods

# Port forward for local testing
kubectl port-forward svc/<service-name> 8080:80
```

#### Useful Azure CLI Commands

```bash
# List resources
az resource list --resource-group k8s-dev-rg -o table

# Check VM status
az vm list --resource-group k8s-dev-rg --show-details -o table

# Get VM logs
az vm run-command invoke --resource-group k8s-dev-rg --name <vm-name> --command-id RunShellScript --scripts "cat /var/log/cloud-init-output.log"

# Check NSG rules
az network nsg rule list --resource-group k8s-dev-rg --nsg-name k8s-dev-rg-nsg -o table

# Check Load Balancer
az network lb show --resource-group k8s-dev-rg --name k8s-dev-rg-lb
```

#### System-Level Debugging

```bash
# SSH to node and check:

# Kubelet status
sudo systemctl status kubelet
sudo journalctl -u kubelet -f

# Containerd status
sudo systemctl status containerd
sudo journalctl -u containerd -f

# Check running containers
sudo crictl ps

# Check container logs
sudo crictl logs <container-id>

# Check disk space
df -h

# Check memory
free -h

# Check network
ip addr
ip route
```

## Getting Help

If you're still stuck:

1. Check logs thoroughly
2. Search GitHub issues
3. Consult Kubernetes documentation
4. Ask in community forums
5. Open a new issue with:
   - Clear problem description
   - Steps to reproduce
   - Environment details
   - Relevant logs and outputs
