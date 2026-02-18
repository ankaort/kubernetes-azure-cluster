#!/bin/bash
set -e

echo "=========================================="
echo "Kubernetes Control Plane Setup Script"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Get the private IP address
PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "Private IP: $PRIVATE_IP"

# Get the public IP address (from Azure metadata service)
PUBLIC_IP=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text")
echo "Public IP: $PUBLIC_IP"

# Create kubeadm configuration
cat > /tmp/kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.28.0
controlPlaneEndpoint: "${PUBLIC_IP}:6443"
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
apiServer:
  certSANs:
  - "${PUBLIC_IP}"
  - "${PRIVATE_IP}"
  - "localhost"
  - "127.0.0.1"
  extraArgs:
    cloud-provider: "external"
controllerManager:
  extraArgs:
    cloud-provider: "external"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: "external"
EOF

echo ""
echo "Initializing Kubernetes control plane..."
kubeadm init --config=/tmp/kubeadm-config.yaml --upload-certs

# Set up kubectl for the default user
ADMIN_USER=${ADMIN_USER:-azureuser}
ADMIN_HOME=$(eval echo ~$ADMIN_USER)

mkdir -p $ADMIN_HOME/.kube
cp -f /etc/kubernetes/admin.conf $ADMIN_HOME/.kube/config
chown -R $ADMIN_USER:$ADMIN_USER $ADMIN_HOME/.kube

echo ""
echo "Installing Calico CNI..."
sudo -u $ADMIN_USER kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml

echo ""
echo "Waiting for Calico pods to be ready..."
sudo -u $ADMIN_USER kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s || true

echo ""
echo "=========================================="
echo "Control plane setup complete!"
echo "=========================================="
echo ""
echo "To join worker nodes to this cluster, run the following command on each worker node:"
echo ""
kubeadm token create --print-join-command
echo ""
echo "Save this join command - you'll need it for the worker nodes!"
echo ""
echo "To use kubectl, run as $ADMIN_USER:"
echo "  export KUBECONFIG=~/.kube/config"
echo "  kubectl get nodes"
echo ""
