#!/bin/bash
# =============================================================
# Prometheus Observability Stack — EC2 Bootstrap Script
# Runs automatically on EC2 first boot via Terraform user-data
# =============================================================
set -e

# Log everything to file and console
exec > >(tee /var/log/monitoring-setup.log | logger -t monitoring-setup -s 2>/dev/console) 2>&1
echo "======================================================"
echo " Overwatch — Kubernetes Observability Stack"
echo " EC2 Setup Starting"
echo " Time: $(date)"
echo "======================================================"

# ── 1. System Updates ─────────────────────────────────────────
echo "[1/8] Updating system packages..."
apt-get update -y
apt-get install -y curl wget git net-tools unzip apt-transport-https ca-certificates gnupg lsb-release

# ── 2. Add Swap Memory (2GB) ──────────────────────────────────
echo "[2/8] Setting up swap memory..."
if [ ! -f /swapfile ]; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  sysctl vm.swappiness=10
  sysctl vm.vfs_cache_pressure=50
  echo "vm.swappiness=10" >> /etc/sysctl.conf
  echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
fi
echo "Swap configured: $(free -h | grep Swap)"

# ── 3. Install Docker ─────────────────────────────────────────
echo "[3/8] Installing Docker..."
apt-get install -y docker.io
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu
echo "Docker installed: $(docker --version)"

# ── 4. Install kubectl ────────────────────────────────────────
echo "[4/8] Installing kubectl..."
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl
echo "kubectl installed: $(kubectl version --client --short)"

# ── 5. Install Kind ───────────────────────────────────────────
echo "[5/8] Installing Kind..."
curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
chmod +x /usr/local/bin/kind
echo "Kind installed: $(kind version)"

# ── 6. Clone Repository ───────────────────────────────────────
echo "[6/8] Cloning monitoring repository..."
REPO_URL="https://github.com/Shubhamx18/overwatch.git"
INSTALL_DIR="/opt/overwatch"

if [ -d "$INSTALL_DIR" ]; then
  cd "$INSTALL_DIR" && git pull origin main
else
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"
echo "Repository ready at $INSTALL_DIR"

# ── 7. Create Kind Cluster ────────────────────────────────────
echo "[7/8] Creating Kubernetes cluster..."
export KUBECONFIG=/root/.kube/config
mkdir -p /root/.kube

# Wait for Docker to be fully ready
sleep 5

kind create cluster \
  --config k8s/kind/kind-cluster-ec2.yaml \
  --name overwatch-cluster \
  --wait 120s

echo "Cluster created: $(kubectl cluster-info)"

# Copy kubeconfig for ubuntu user too
mkdir -p /home/ubuntu/.kube
cp /root/.kube/config /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# ── 8. Deploy Monitoring Stack ────────────────────────────────
echo "[8/8] Deploying monitoring stack..."

kubectl apply --server-side -f k8s/namespace/
sleep 5

kubectl apply --server-side -f k8s/prometheus/
kubectl apply --server-side -f k8s/alertmanager/
kubectl apply --server-side -f k8s/grafana/
kubectl apply --server-side -f k8s/node-exporter/
kubectl apply --server-side -f k8s/kube-state-metrics/
kubectl apply --server-side -f k8s/blackbox-exporter/

echo "Waiting for pods to be ready (up to 5 minutes)..."
kubectl wait --for=condition=ready pod --all -n monitoring --timeout=300s || true

# ── Final Status ──────────────────────────────────────────────
echo ""
echo "======================================================"
echo " Overwatch Setup Complete!"
echo " Time: $(date)"
echo "======================================================"
echo ""
echo " Access your monitoring stack:"
echo "   Grafana      → http://$(curl -s ifconfig.io):3000"
echo "   Prometheus   → http://$(curl -s ifconfig.io):9090"
echo "   Alertmanager → http://$(curl -s ifconfig.io):9093"
echo ""
echo " Credentials: admin / admin@123"
echo ""
kubectl get pods -n monitoring
echo "======================================================"
