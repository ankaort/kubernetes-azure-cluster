#!/bin/bash
set -e

echo "=========================================="
echo "Kubernetes Worker Node Setup Script"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Check if join command is provided
if [ -z "$1" ]; then
    echo "Usage: $0 '<kubeadm join command>'"
    echo ""
    echo "Example:"
    echo "  sudo $0 'kubeadm join 10.0.1.4:6443 --token abcdef.0123456789abcdef --discovery-token-ca-cert-hash sha256:xxxxx'"
    echo ""
    echo "Get the join command by running this on the control plane:"
    echo "  sudo kubeadm token create --print-join-command"
    exit 1
fi

JOIN_COMMAND="$@"

echo "Joining cluster with command:"
echo "$JOIN_COMMAND"
echo ""

# Execute the join command
eval $JOIN_COMMAND

echo ""
echo "=========================================="
echo "Worker node setup complete!"
echo "=========================================="
echo ""
echo "Verify the node joined successfully by running on the control plane:"
echo "  kubectl get nodes"
echo ""
