# Deployment Checklist

Use this checklist to ensure a successful deployment of your Kubernetes cluster on Azure.

## Pre-Deployment

### Azure Account Setup
- [ ] Azure subscription is active
- [ ] Sufficient quota for resources:
  - [ ] 3 VMs (D2s_v3 and E2s_v3)
  - [ ] 3 Public IPs
  - [ ] 1 Load Balancer
  - [ ] Storage account
- [ ] Billing alerts configured
- [ ] Cost limits understood (~$180-250/month)

### Local Environment
- [ ] Azure CLI installed (v2.30.0+)
- [ ] Terraform installed (v1.0+)
- [ ] kubectl installed (v1.28+)
- [ ] SSH key pair generated
- [ ] Git installed
- [ ] jq installed (for parsing outputs)

### Authentication
- [ ] Logged in to Azure CLI: `az login`
- [ ] Correct subscription selected: `az account set`
- [ ] Permissions verified:
  - [ ] Can create resource groups
  - [ ] Can create VMs
  - [ ] Can create networking resources
  - [ ] Can assign roles

## Infrastructure Deployment

### Terraform Configuration
- [ ] Repository cloned
- [ ] `terraform.tfvars` created from example
- [ ] Variables customized:
  - [ ] `resource_group_name` set
  - [ ] `location` set to preferred region
  - [ ] `ssh_public_key_path` points to valid key
  - [ ] `admin_username` set
  - [ ] VM sizes appropriate for use case
- [ ] Terraform initialized: `terraform init`
- [ ] Terraform validated: `terraform validate`
- [ ] Terraform plan reviewed: `terraform plan`

### Infrastructure Apply
- [ ] `terraform apply` completed successfully
- [ ] All resources created:
  - [ ] Resource group
  - [ ] Virtual network and subnet
  - [ ] Network security group
  - [ ] 3 VMs (1 control plane + 2 workers)
  - [ ] 3 Public IPs for VMs
  - [ ] 1 Public IP for Load Balancer
  - [ ] Load Balancer with backend pool
  - [ ] Storage account
  - [ ] Availability set
- [ ] Outputs saved: `terraform output > outputs.txt`
- [ ] VMs are running: `az vm list -g <rg> --show-details`
- [ ] Can SSH to control plane
- [ ] Can SSH to both workers

### VM Initialization
- [ ] Cloud-init completed (check `/var/log/cloud-init-output.log`)
- [ ] VMs have rebooted after cloud-init
- [ ] containerd is running on all VMs
- [ ] kubeadm is installed on all VMs
- [ ] kubelet is installed but not running yet (expected)

## Kubernetes Cluster Setup

### Control Plane
- [ ] `setup-control-plane.sh` script copied to control plane
- [ ] Script executed: `sudo ./setup-control-plane.sh`
- [ ] Initialization completed without errors
- [ ] Join command copied and saved
- [ ] kubectl works from control plane: `kubectl get nodes`
- [ ] Calico pods are running: `kubectl get pods -n kube-system`
- [ ] Control plane node shows Ready status

### Worker Nodes
- [ ] `setup-worker.sh` script copied to both workers
- [ ] Worker 1 joined successfully
- [ ] Worker 2 joined successfully
- [ ] Both workers show Ready status: `kubectl get nodes`
- [ ] All nodes visible in cluster

### Local kubectl Access
- [ ] kubeconfig copied from control plane
- [ ] KUBECONFIG environment variable set
- [ ] `kubectl get nodes` works from local machine
- [ ] All nodes showing Ready status
- [ ] Can access cluster remotely

## Storage Setup

### Azure CSI Drivers
- [ ] CSI driver installation script copied
- [ ] Azure Disk CSI driver installed
- [ ] Azure Blob CSI driver installed
- [ ] CSI driver pods running:
  - [ ] csi-azuredisk-controller
  - [ ] csi-azuredisk-node (on all nodes)
  - [ ] csi-blob-controller
  - [ ] csi-blob-node (on all nodes)

### Storage Classes
- [ ] `storage-class.yaml` applied
- [ ] Storage classes created:
  - [ ] azure-disk-standard (default)
  - [ ] azure-disk-premium
  - [ ] azure-blob
- [ ] Default storage class set

### Blob Storage Access
- [ ] Storage account name retrieved from terraform output
- [ ] Storage account key retrieved (securely)
- [ ] Kubernetes secret created: `azure-storage-secret`
- [ ] ConfigMap created: `azure-storage-config`
- [ ] Managed identity roles assigned to VMs

## Application Deployment

### MongoDB
- [ ] `mongodb-statefulset.yaml` applied
- [ ] Pod is running: `kubectl get pod mongodb-0`
- [ ] PVC bound: `kubectl get pvc mongodb-data-mongodb-0`
- [ ] Service created: `kubectl get svc mongodb`
- [ ] MongoDB accessible: `kubectl exec mongodb-0 -- mongosh --eval "db.version()"`
- [ ] Data persists after pod restart

### Redis
- [ ] `redis-statefulset.yaml` applied
- [ ] Pod is running: `kubectl get pod redis-0`
- [ ] PVC bound: `kubectl get pvc redis-data-redis-0`
- [ ] Service created: `kubectl get svc redis`
- [ ] Redis accessible: test with redis-cli
- [ ] AOF persistence enabled

### Jetty
- [ ] `jetty-deployment.yaml` applied
- [ ] Pods are running: `kubectl get pods -l app=jetty`
- [ ] PVC bound: `kubectl get pvc jetty-data`
- [ ] Service created: `kubectl get svc jetty`
- [ ] LoadBalancer IP assigned (may take 2-5 minutes)
- [ ] Application accessible via external IP
- [ ] Both replicas responding

## Validation

### Cluster Health
- [ ] All nodes Ready: `kubectl get nodes`
- [ ] All system pods running: `kubectl get pods -n kube-system`
- [ ] No crashlooping pods: `kubectl get pods --all-namespaces`
- [ ] No pending PVCs: `kubectl get pvc --all-namespaces`
- [ ] Cluster info accessible: `kubectl cluster-info`

### Networking
- [ ] Pod-to-pod communication works
- [ ] Pod-to-service communication works
- [ ] Service DNS resolution works
- [ ] LoadBalancer service has external IP
- [ ] Can access Jetty from internet
- [ ] NSG rules are appropriate

### Storage
- [ ] Can create PVCs dynamically
- [ ] PVCs bind to PVs correctly
- [ ] Volumes mount in pods
- [ ] Applications can read/write to volumes
- [ ] Data persists after pod deletion
- [ ] Volume expansion works if needed

### Monitoring
- [ ] Can view metrics: `kubectl top nodes`
- [ ] Can view metrics: `kubectl top pods`
- [ ] Can view logs: `kubectl logs <pod>`
- [ ] Events are recorded: `kubectl get events`

## Post-Deployment

### Documentation
- [ ] README.md reviewed
- [ ] Architecture documentation reviewed
- [ ] Troubleshooting guide reviewed
- [ ] Team members have access to documentation

### Security
- [ ] Default passwords changed in MongoDB
- [ ] Default passwords changed in Redis
- [ ] SSH keys secured (not committed to git)
- [ ] Terraform state secured
- [ ] Storage keys not exposed
- [ ] NSG rules reviewed and restricted

### Backup and DR
- [ ] Backup strategy defined
- [ ] Critical data backed up
- [ ] Recovery procedures documented
- [ ] Tested restore process

### Monitoring and Alerting
- [ ] Azure Monitor configured
- [ ] Cost alerts set up
- [ ] Resource alerts configured
- [ ] Log aggregation set up (optional)

### Cleanup Plan
- [ ] Understand teardown process
- [ ] Know what gets deleted
- [ ] Backup important data before cleanup
- [ ] Document any persistent data locations

## Troubleshooting Checklist

If something doesn't work, check:

### Infrastructure Issues
- [ ] Terraform state is consistent
- [ ] All Azure resources created
- [ ] VMs are running
- [ ] SSH access works
- [ ] Cloud-init completed successfully
- [ ] NSG rules allow required traffic

### Cluster Issues
- [ ] kubelet running on all nodes
- [ ] containerd running on all nodes
- [ ] CNI pods running
- [ ] No certificate issues
- [ ] Time synchronized across nodes
- [ ] Firewall/iptables not blocking

### Application Issues
- [ ] Pods have correct images
- [ ] Resource requests/limits reasonable
- [ ] PVCs bound correctly
- [ ] Secrets and ConfigMaps exist
- [ ] Service selectors match pod labels
- [ ] Network policies not blocking

## Sign-Off

### Team Review
- [ ] Infrastructure reviewed by: _________________ Date: _______
- [ ] Security reviewed by: _________________ Date: _______
- [ ] Application owner approved: _________________ Date: _______

### Go-Live Approval
- [ ] All checks passed
- [ ] Team trained on operations
- [ ] Monitoring configured
- [ ] Backup/restore tested
- [ ] Incident response plan ready

**Deployment approved by:** _________________ **Date:** _______

---

## Notes

Add any deployment-specific notes here:

```
[Your notes]
```

## Issues Encountered

Document any issues and resolutions:

```
[Issues and resolutions]
```
