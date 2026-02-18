#!/bin/bash
set -e

echo "=========================================="
echo "Configuring Storage Classes"
echo "=========================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "kubectl not found. Please ensure kubectl is installed and configured."
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
K8S_DIR="$SCRIPT_DIR/../kubernetes"

echo ""
echo "Applying storage class configuration..."
kubectl apply -f "$K8S_DIR/storage-class.yaml"

echo ""
echo "Verifying storage classes..."
kubectl get storageclass

echo ""
echo "=========================================="
echo "Storage configuration complete!"
echo "=========================================="
echo ""
echo "Available storage classes:"
kubectl get storageclass -o wide
echo ""
