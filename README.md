# 🔭 Overwatch — Kubernetes Observability Stack

> A production-grade monitoring platform that watches your infrastructure, predicts problems before they happen, and tells you exactly how much your AWS bill will be — all in one place.

---

## 🏗️ Architecture

```
                    You (Browser)
                         │
              http://EC2-PUBLIC-IP:3000
                         │
    ┌────────────────────▼─────────────────────┐
    │            AWS EC2 (via Terraform)        │
    │                                           │
    │   ┌───────────────────────────────────┐   │
    │   │      Kubernetes Cluster (Kind)    │   │
    │   │                                   │   │
    │   │  Node Exporter  ──┐               │   │
    │   │  kube-state-metrics─┤             │   │
    │   │  cAdvisor        ──┼──► Prometheus│   │
    │   │  Blackbox Exporter─┘       │      │   │
    │   │                            ▼      │   │
    │   │                      Alertmanager │   │
    │   │                            │      │   │
    │   │                      Slack/Email  │   │
    │   │                                   │   │
    │   │  Grafana ◄──────── Prometheus     │   │
    │   └───────────────────────────────────┘   │
    └───────────────────────────────────────────┘
```

---

## 📦 Stack Components

| Component | Version | Port | Purpose |
|---|---|---|---|
| Prometheus | v2.51.0 | 9090 | Metrics collection & storage |
| Grafana | 11.0.0 | 3000 | Dashboards & visualization |
| Alertmanager | v0.27.0 | 9093 | Alert routing (Slack + Email) |
| Node Exporter | v1.7.0 | 9100 | Host CPU/RAM/Disk metrics |
| kube-state-metrics | v2.12.0 | 8080 | Kubernetes object health |
| Blackbox Exporter | v0.25.0 | 9115 | URL uptime + SSL monitoring |

---

## ⚡ Quick Start (Local)

### Prerequisites
- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

### Run Locally

```bash
# 1. Clone the repo
git clone https://github.com/your-username/overwatch.git
cd overwatch

# 2. Create Kind cluster
kind create cluster --config k8s/kind/kind-cluster.yaml --name overwatch-cluster

# 3. Deploy the full stack
kubectl apply -f k8s/namespace/
kubectl apply -f k8s/prometheus/
kubectl apply -f k8s/alertmanager/
kubectl apply -f k8s/grafana/
kubectl apply -f k8s/grafana/finops-dashboard-configmap.yaml
kubectl apply -f k8s/node-exporter/
kubectl apply -f k8s/kube-state-metrics/
kubectl apply -f k8s/blackbox-exporter/

# 4. Wait for all pods
kubectl wait --for=condition=ready pod --all -n monitoring --timeout=300s
```

### Access (Local)
| Service | URL | Credentials |
|---|---|---|
| Grafana | http://localhost:13000 | admin / admin@123 |
| Prometheus | http://localhost:19090 | — |
| Alertmanager | http://localhost:19093 | — |

---

## ☁️ Deploy on AWS EC2 (Terraform)

```bash
# 1. Update terraform-aws/vars/ec2.tfvars with your:
#    - AWS region
#    - VPC ID
#    - Subnet ID
#    - Key pair name

# 2. Update terraform-aws/modules/ec2/user-data.sh with your:
#    - GitHub repo URL

# 3. Deploy
cd terraform-aws/prometheus-stack
terraform init
terraform apply -var-file=../vars/ec2.tfvars
```

EC2 boots → installs everything → deploys Overwatch automatically.

Access Grafana at: `http://EC2-PUBLIC-IP:3000`

---

## 🚨 Alert Rules (19 Total)

### Node Alerts
| Alert | Trigger | Severity |
|---|---|---|
| NodeDown | Node unreachable > 1m | 🔴 critical |
| HighCPUUsage | CPU > 85% for 2m | 🟡 warning |
| HighMemoryUsage | RAM > 85% for 2m | 🟡 warning |
| HighDiskUsage | Disk > 85% for 1m | 🟡 warning |
| DiskWillFillIn4Hours | Predicted < 4h | 🔴 critical |
| DiskWillFillIn24Hours | Predicted < 24h | 🟡 warning |

### Kubernetes Alerts
| Alert | Trigger | Severity |
|---|---|---|
| PodCrashLooping | > 3 restarts in 15m | 🔴 critical |
| PodNotReady | Not ready > 5m | 🟡 warning |
| PodOOMKilled | Killed by OOM | 🔴 critical |
| DeploymentReplicasMismatch | Desired ≠ Available | 🟡 warning |
| DeploymentRolloutStuck | Stuck > 15m | 🟡 warning |

### Uptime Alerts
| Alert | Trigger | Severity |
|---|---|---|
| EndpointDown | Probe failed > 1m | 🔴 critical |
| SlowResponse | Response > 2s | 🟡 warning |
| SSLCertExpiringIn7Days | SSL < 7 days | 🔴 critical |
| SSLCertExpiringIn30Days | SSL < 30 days | 🟡 warning |

### FinOps Alerts
| Alert | Trigger | Severity |
|---|---|---|
| InstanceOverProvisioned | CPU < 10% for 7 days | ℹ️ info |
| MemoryGrowthDetected | RAM full predicted in 14d | 🟡 warning |
| DiskGrowthDetected | Disk full predicted in 14d | 🟡 warning |

---

## 📊 Grafana Dashboards

### Auto-loaded (no setup needed)
- 💰 **FinOps — AWS Cost Intelligence** ← unique feature

### Import manually (Grafana → Dashboards → Import)
| Dashboard | ID | Shows |
|---|---|---|
| Node Exporter Full | `1860` | CPU, RAM, Disk, Network |
| Kubernetes Cluster | `7249` | Pod & deployment health |
| kube-state-metrics | `13332` | K8s object status |
| Blackbox Uptime | `7587` | URL uptime & SSL |

---

## 🔄 CI/CD Pipeline

Push code → GitHub Actions automatically:
1. ✅ Validates all Kubernetes YAML files
2. 🔒 Security scans (Trivy + tfsec + Checkov)
3. 🧪 Deploys to Kind and verifies all pods are healthy
4. 🚀 Deploys to EC2 (main branch only)
5. 📢 Sends Slack notification on success/failure

### GitHub Secrets Required
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
PROD_SERVER_IP
PROD_SSH_KEY
SLACK_WEBHOOK_URL
```

---

## 📁 Project Structure

```
overwatch/
│
├── .github/
│   └── workflows/
│       └── deploy.yml          ← CI/CD Pipeline
│
├── k8s/
│   ├── kind/
│   │   ├── kind-cluster.yaml   ← Local cluster config
│   │   └── kind-cluster-ec2.yaml ← EC2 cluster config
│   ├── namespace/              ← monitoring namespace
│   ├── prometheus/             ← Metrics + 19 Alert Rules + RBAC
│   ├── alertmanager/           ← Smart routing + Inhibition rules
│   ├── grafana/                ← Dashboards auto-provisioned + FinOps
│   ├── node-exporter/          ← DaemonSet on every node
│   ├── kube-state-metrics/     ← K8s object monitoring
│   └── blackbox-exporter/      ← URL uptime + SSL
│
├── terraform-aws/
│   ├── modules/
│   │   ├── ec2/                ← EC2 + auto-deploy script
│   │   └── security-group/     ← Firewall rules
│   └── prometheus-stack/       ← Main Terraform config
│
├── .env.example                ← Credentials template
├── .gitignore                  ← Secrets protection
├── Makefile                    ← One-command automation
└── README.md                   ← This file
```

---

## 🔐 Security

- All secrets stored in Kubernetes Secrets
- `.env` file excluded from git
- Security scanning in CI/CD (Trivy, tfsec, Checkov)
- Alert inhibition rules prevent alert storms
- Node Exporter runs with read-only root filesystem
- kube-state-metrics runs as non-root user

---

## 💰 FinOps — Cost Intelligence (Unique Feature)

Overwatch includes a **custom cost prediction dashboard** that:
- Shows EC2 resource utilization (CPU/RAM/Disk) averaged over 24 hours
- Predicts when you'll need a bigger instance (using `predict_linear()`)
- Alerts when your instance is over-provisioned (wasting money)
- Alerts when resources are growing fast (cost increase incoming)

**This feature doesn't exist in any other open-source monitoring stack.**

---

## 🏆 What Makes Overwatch Stand Out

| Feature | Basic Projects | Overwatch |
|---|---|---|
| Kubernetes-native | ❌ | ✅ |
| Container metrics | ❌ | ✅ cAdvisor |
| URL uptime + SSL | ❌ | ✅ Blackbox |
| Predictive alerts | ❌ | ✅ predict_linear() |
| CI/CD + security scan | ❌ | ✅ Trivy + tfsec |
| Smart alert routing | ❌ | ✅ Severity-based |
| FinOps cost dashboard | ❌ | ✅ Unique feature |
| One-command deploy | ❌ | ✅ Terraform |
