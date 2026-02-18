#!/bin/bash
set -e

echo "=========================================="
echo "Installing Azure CSI Drivers"
echo "=========================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "kubectl not found. Please ensure kubectl is installed and configured."
    exit 1
fi

echo ""
echo "Installing Azure Disk CSI Driver..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/install-driver.sh | bash

echo ""
echo "Waiting for Azure Disk CSI Driver pods to be ready..."
kubectl wait --for=condition=ready pod -l app=csi-azuredisk-controller -n kube-system --timeout=300s || true
kubectl wait --for=condition=ready pod -l app=csi-azuredisk-node -n kube-system --timeout=300s || true

echo ""
echo "Installing Azure Blob CSI Driver..."
curl -skSL https://raw.githubusercontent.com/kubernetes-sigs/blob-csi-driver/master/deploy/install-driver.sh | bash -s master --

echo ""
echo "Waiting for Azure Blob CSI Driver pods to be ready..."
kubectl wait --for=condition=ready pod -l app=csi-blob-controller -n kube-system --timeout=300s || true
kubectl wait --for=condition=ready pod -l app=csi-blob-node -n kube-system --timeout=300s || true

echo ""
echo "=========================================="
echo "Verifying CSI Drivers..."
echo "=========================================="
echo ""
echo "Azure Disk CSI Driver pods:"
kubectl get pods -n kube-system -l app=csi-azuredisk-controller
kubectl get pods -n kube-system -l app=csi-azuredisk-node
echo ""
echo "Azure Blob CSI Driver pods:"
kubectl get pods -n kube-system -l app=csi-blob-controller
kubectl get pods -n kube-system -l app=csi-blob-node
echo ""
echo "CSI Drivers installation complete!"
echo ""
