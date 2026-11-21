<div align="center">

# 🔭 Overwatch

### Kubernetes Monitoring, Alerting & FinOps Platform on AWS

Watch a Kubernetes cluster, get alerted when something breaks, and see what it costs, all deployed automatically with Terraform and GitHub Actions.

[![CI/CD](https://github.com/Shubhamx18/overwatch/actions/workflows/deploy.yml/badge.svg)](https://github.com/Shubhamx18/overwatch/actions/workflows/deploy.yml)
![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-F46800?logo=grafana&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-232F3E?logo=amazonaws&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?logo=githubactions&logoColor=white)

<br><br>

<img src="https://raw.githubusercontent.com/Shubhamx18/overwatch/main/assets/grafana-kubernetes-cluster.png" alt="Overwatch Kubernetes cluster dashboard" width="900">

</div>

---

## 📑 Table of Contents

1. [Overview](#-1-overview)
2. [How It Works](#-2-how-it-works)
3. [Project Tour (Screenshots)](#-3-project-tour-screenshots)
4. [Tech Stack](#-4-tech-stack)
5. [Project Structure](#-5-project-structure)
6. [Getting Started](#-6-getting-started)
7. [Access the Tools](#-7-access-the-tools)
8. [FinOps: Cost Intelligence](#-8-finops-cost-intelligence)
9. [CI/CD Pipeline](#-9-cicd-pipeline)
10. [Design Decisions](#-10-design-decisions)
11. [Security Notes](#-11-security-notes)
12. [Daily Operations](#-12-daily-operations)
13. [Troubleshooting](#-13-troubleshooting)
14. [Roadmap](#-14-roadmap)

---

## 📌 1. Overview

### The problem

Servers and clusters fail quietly. Without monitoring, you find out about a crash from your users, and you find out about wasted cloud spend from the bill at the end of the month.

### What Overwatch does

Overwatch is a production-style **observability stack** running on a Kubernetes (kind) cluster on an AWS EC2 server. It answers three questions:

| Question | Answered by |
|---|---|
| **Is my cluster healthy?** | Prometheus metrics shown in Grafana dashboards |
| **Will I know when something breaks?** | Alertmanager with smart routing and inhibition |
| **What is this costing me?** | FinOps dashboard with utilization and cost projections |

Everything is code. **Terraform** creates the server, **Kubernetes manifests** deploy the stack, and a **GitHub Actions pipeline** validates, tests and deploys every push to `main`.

### Features

- **Cluster monitoring**: nodes, pods and Kubernetes objects scraped by Prometheus
- **Auto-provisioned dashboards**: Grafana loads the main dashboards on startup
- **Smart alerting**: Alertmanager routing and inhibition rules
- **Uptime and SSL checks**: websites probed with Blackbox Exporter
- **FinOps dashboard**: CPU, RAM and disk utilization plus EC2 cost projections
- **Infrastructure as Code**: EC2, security group and default VPC detection with Terraform
- **Zero-touch boot**: the server installs Docker, kind and kubectl, then deploys the stack by itself
- **CI/CD**: manifest validation, integration test on a kind cluster, automatic deployment

---

## ⚙️ 2. How It Works

### Architecture

```
                         ┌─────────────────────────┐
   git push ───────────► │     GitHub Actions      │
                         │ validate → test → deploy│
                         └────────────┬────────────┘
                                      │ SSH
                                      ▼
┌──────────────────── AWS EC2 (t3.medium, ap-south-1) ─────────────────────┐
│                                                                          │
│  ┌──────────────────── kind Kubernetes cluster ──────────────────────┐   │
│  │                    namespace: monitoring                          │   │
│  │                                                                   │   │
│  │  Node Exporter ───────┐                                           │   │
│  │  kube-state-metrics ──┼──►  Prometheus  ──►  Grafana (dashboards) │   │
│  │  Blackbox Exporter ───┘         │                                 │   │
│  │                                 ▼                                 │   │
│  │                           Alertmanager ──► notifications          │   │
│  └───────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────┘
        ▲
        │ created by
   Terraform (EC2 + Security Group)
```

### The data flow, step by step

1. **Terraform** creates the EC2 server and its firewall.
2. On first boot, the server **installs Docker, kind and kubectl**, clones this repo and creates the cluster.
3. The **exporters** expose metrics: Node Exporter (machine), kube-state-metrics (Kubernetes objects), Blackbox Exporter (URL and SSL checks).
4. **Prometheus** scrapes every exporter on a schedule, stores the data and evaluates alert and recording rules.
5. **Grafana** reads from Prometheus and draws the dashboards.
6. When a rule fires, **Alertmanager** groups, routes and sends the alert.
7. Every `git push` runs the **pipeline**, which redeploys the manifests to the server.

### Components

| Component | Role |
|---|---|
| **Prometheus** | Collects and stores metrics, evaluates alert and recording rules |
| **Grafana** | Dashboards for FinOps, nodes and the Kubernetes cluster |
| **Alertmanager** | Routes, groups and sends alerts |
| **Node Exporter** | Machine metrics (CPU, RAM, disk, network), one per node |
| **kube-state-metrics** | Kubernetes object metrics (pods, deployments, nodes) |
| **Blackbox Exporter** | Probes URLs for uptime and SSL expiry |

---

## 📸 3. Project Tour (Screenshots)

This is what the running stack looks like, in the order data flows through it: server, alerting, cluster, cost, workload.

### Step 1: The server (AWS EC2)

Terraform creates a `t3.medium` instance in `ap-south-1` inside the default VPC. Everything below runs on this one machine.

![AWS EC2 instance running the stack](https://raw.githubusercontent.com/Shubhamx18/overwatch/main/assets/aws-ec2-instance.png)

### Step 2: Alerting (Alertmanager)

Alertmanager reports `ready`. This is where Prometheus sends alerts, so you hear about problems before your users do.

![Alertmanager status](https://raw.githubusercontent.com/Shubhamx18/overwatch/main/assets/alertmanager-status.png)

### Step 3: The whole cluster (Grafana)

The big picture: how much of the cluster's pod, CPU and memory capacity is already requested by workloads. This is the starting point for right-sizing decisions.

![Kubernetes cluster requests and capacity](https://raw.githubusercontent.com/Shubhamx18/overwatch/main/assets/grafana-kubernetes-cluster.png)

### Step 4: Cost and utilization (FinOps dashboard)

Current CPU, RAM and disk utilization for each node, with trends over time. Low usage next to a steady cost is how you spot over-provisioned resources.

![FinOps resource utilization](https://raw.githubusercontent.com/Shubhamx18/overwatch/main/assets/finops-resource-utilization.png)

Capacity forecasting predicts RAM usage for the next 14 days, so you can see whether you will run out before it happens.

![FinOps capacity forecast](https://raw.githubusercontent.com/Shubhamx18/overwatch/main/assets/finops-capacity-forecast.png)

### Step 5: The workloads (pod and node health)

Are the pods healthy? Running count, restarts, CPU idle and node storage at a glance.

![Pod and node health](https://raw.githubusercontent.com/Shubhamx18/overwatch/main/assets/finops-pod-node-health.png)

> **Reading the screenshots:** cluster, cost and pod views are all driven by the same Prometheus data. Only the zoom level changes.

---

## 🧰 4. Tech Stack

| Area | Tools |
|---|---|
| **Monitoring** | Prometheus, Node Exporter, kube-state-metrics, Blackbox Exporter |
| **Visualization** | Grafana |
| **Alerting** | Alertmanager |
| **Orchestration** | Kubernetes (kind), kubectl |
| **Infrastructure** | Terraform, AWS EC2, Security Groups |
| **CI/CD** | GitHub Actions, kubeconform |

---

## 📁 5. Project Structure

```
overwatch/
├── .github/workflows/
│   └── deploy.yml              # CI/CD pipeline
├── assets/                     # Screenshots used in this README
├── k8s/
│   ├── kind/                   # kind cluster configs (local and EC2)
│   ├── namespace/              # monitoring namespace
│   ├── prometheus/             # Prometheus, alert rules, FinOps recording rules, kubelet RBAC
│   ├── alertmanager/           # Alertmanager config and routing
│   ├── grafana/                # Grafana + auto-provisioned dashboards
│   ├── node-exporter/          # DaemonSet on every node
│   ├── kube-state-metrics/     # Kubernetes object metrics + RBAC
│   └── blackbox-exporter/      # URL and SSL probing
├── terraform-aws/
│   ├── modules/
│   │   ├── ec2/                # EC2 instance + user-data boot script
│   │   └── security-group/     # Firewall rules
│   └── prometheus-stack/       # Main Terraform config and variables
├── Makefile
├── .env.example
└── README.md
```

---

## 🚀 6. Getting Started

### Prerequisites

- An **AWS account** with an access key, and an EC2 **key pair**
- [Terraform](https://developer.hashicorp.com/terraform/install)
- [AWS CLI](https://aws.amazon.com/cli/)
- Git

### Step 1: Clone the repo

```bash
git clone https://github.com/Shubhamx18/overwatch.git
cd overwatch
```

### Step 2: Configure AWS

```bash
aws configure
```

| Prompt | Value |
|---|---|
| Access Key ID | your AWS access key |
| Secret Access Key | your AWS secret key |
| Region | `ap-south-1` |
| Output format | `json` |

### Step 3: Set your key pair name

Open `terraform-aws/prometheus-stack/terraform.tfvars`:

```hcl
key_name = "your-key-pair-name"   # AWS Console → EC2 → Key Pairs
```

### Step 4: Create the server with Terraform

```bash
cd terraform-aws/prometheus-stack
terraform init
terraform apply
```

Type `yes`. Terraform prints the server details:

```
ec2_public_ip = "X.X.X.X"
grafana_url   = "http://X.X.X.X:3000"
ssh_command   = "ssh -i <key>.pem ubuntu@X.X.X.X"
```

> **Save the IP.** The VPC and subnets are detected automatically from your default VPC, so no IDs need to be pasted.

### Step 5: Wait for the first boot (about 5 minutes)

The server automatically:

1. Installs Docker, kind and kubectl
2. Clones this repository
3. Creates the kind cluster
4. Deploys all monitoring components

Check progress:

```bash
ssh -i <key>.pem ubuntu@<EC2-IP> "kubectl get pods -n monitoring"
ssh -i <key>.pem ubuntu@<EC2-IP> "tail -f /var/log/monitoring-setup.log"
```

You should see **8 pods Running**: alertmanager, blackbox-exporter, grafana, kube-state-metrics, prometheus, and one node-exporter on each of the 3 nodes.

### Step 6: Open the tools

Continue to [Access the Tools](#-7-access-the-tools).

---

## 🌐 7. Access the Tools

| Tool | URL | What to check |
|---|---|---|
| **Grafana** | `http://<EC2-IP>:3000` | Dashboards (log in with the credentials set in the Grafana manifest) |
| **Prometheus** | `http://<EC2-IP>:9090` | `/targets` should show everything **UP** |
| **Alertmanager** | `http://<EC2-IP>:9093` | Active and silenced alerts |
| **Blackbox Exporter** | `http://<EC2-IP>:9115` | Probe results |

> Use `http://`, not `https://`. Change the default Grafana password after your first login.

### Dashboards

- **FinOps: Cost Intelligence**: loads automatically
- **Node Exporter**: loads automatically

Import these community dashboards (**Dashboards → New → Import**) and pick the Prometheus data source:

| ID | Dashboard |
|---|---|
| `1860` | Node Exporter Full |
| `7249` | Kubernetes Cluster |
| `13332` | kube-state-metrics |

---

## 💰 8. FinOps: Cost Intelligence

Overwatch turns monitoring data into cost visibility. Prometheus **recording rules** pre-compute these metrics every 15 seconds so dashboards load instantly:

| Metric | Meaning |
|---|---|
| `finops:cpu_utilization_24h` | Current CPU usage % |
| `finops:ram_utilization_24h` | Current RAM usage % |
| `finops:disk_utilization` | Current disk usage % |
| `finops:total_ram_gb` | Total RAM in GB |
| `finops:ec2_hourly_cost_usd` | EC2 cost per hour (t3.medium, ap-south-1) |
| `finops:ec2_session_cost_usd` | Cost since the instance booted |
| `finops:ec2_daily_cost_usd` | Projected daily cost |
| `finops:ec2_monthly_cost_usd` | Projected monthly cost |

**How to read it:** low utilization next to a steady cost means a resource is over-provisioned and can be right-sized. That gap is where the savings are.

---

## 🔄 9. CI/CD Pipeline

Every push to `main` runs three stages (`.github/workflows/deploy.yml`):

| Stage | What it does |
|---|---|
| **1. Validate** | Checks all Kubernetes manifests with `kubeconform` (about 1 min) |
| **2. Integration Test** | Spins up a kind cluster, deploys all components, verifies Prometheus and Grafana are healthy (about 5 min) |
| **3. Deploy** | SSHes into EC2, runs `git pull` and `kubectl apply --server-side` (about 1 min) |

### Set up the pipeline

**Add repository secrets** at *Settings → Secrets and variables → Actions*:

| Secret | Value |
|---|---|
| `PROD_SERVER_IP` | Public IP of your EC2 |
| `PROD_SSH_KEY` | Full contents of your `.pem` file, including the `BEGIN` and `END` lines |
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |

**Create an environment** at *Settings → Environments → New environment* named `production`.

Then push:

```bash
git add .
git commit -m "your change"
git push origin main
```

### After a Prometheus config change

`kubectl apply` updates the ConfigMap, but Prometheus only reads its config at startup. Restart it to pick up new alert rules, recording rules and scrape configs:

```bash
ssh -i <key>.pem ubuntu@<EC2-IP> \
  "export KUBECONFIG=/home/ubuntu/.kube/config && \
   kubectl rollout restart deployment prometheus grafana -n monitoring"
```

---

## 🧠 10. Design Decisions

**Grafana dashboards are auto-provisioned.** The dashboard JSON lives in a ConfigMap, is mounted into the Grafana pod, and a provider ConfigMap tells Grafana to load it on startup. No manual import is needed for the main dashboards.

**`kubectl apply --server-side` everywhere.** The Node Exporter dashboard JSON is about 300 KB. A normal `kubectl apply` stores the full config in an annotation, which has a 262 KB limit and fails. Server-side apply has no such limit.

**Default VPC auto-detection.** Terraform finds your default VPC and subnets with data sources, so there are no hardcoded IDs.

**Prometheus kubelet RBAC fix.** `k8s/prometheus/kubelet-rbac.yaml` grants Prometheus access to kubelet metrics. Without it, the `kubernetes-nodes` and `kubernetes-cadvisor` targets return 403.

**Different ports locally and on EC2.** The local kind config (`kind-cluster.yaml`) uses Grafana `13000` and Prometheus `19090` to avoid port conflicts. The EC2 config (`kind-cluster-ec2.yaml`) uses the standard `3000` and `9090`.

---

## 🔒 11. Security Notes

| Port | Service |
|---|---|
| 22 | SSH |
| 3000 | Grafana |
| 9090 | Prometheus |
| 9093 | Alertmanager |
| 9115 | Blackbox Exporter |

- The security group rules default to `0.0.0.0/0` for easy testing. For anything beyond a demo, restrict at least SSH to your own IP (`curl ifconfig.io`).
- Change the default Grafana password after the first login.
- Never commit your `.pem` key or AWS credentials. Secrets belong in GitHub Actions secrets.

---

## 🛠️ 12. Daily Operations

**EC2 IP changed after a stop/start?** A normal public IP changes whenever the instance is stopped and started.

```bash
terraform output ec2_public_ip      # get the new IP
# then update the PROD_SERVER_IP GitHub secret
```

For a permanent IP, allocate an **Elastic IP** (AWS Console → EC2 → Elastic IPs) and associate it with the instance. AWS charges for public IPv4 addresses.

**Restart a component**

```bash
ssh -i <key>.pem ubuntu@<EC2-IP> \
  "export KUBECONFIG=/home/ubuntu/.kube/config && \
   kubectl rollout restart deployment prometheus -n monitoring"
```

**Stop paying: destroy everything**

```bash
cd terraform-aws/prometheus-stack
terraform destroy
```

**Bring it back**

```bash
terraform apply     # then wait about 5 minutes for the boot script
```

### Quick reference

| What | Command / URL |
|---|---|
| SSH into EC2 | `ssh -i <key>.pem ubuntu@<EC2-IP>` |
| Check pods | `kubectl get pods -n monitoring` |
| Prometheus targets | `http://<EC2-IP>:9090/targets` |
| Boot log | `tail -f /var/log/monitoring-setup.log` |
| Create / destroy EC2 | `terraform apply` / `terraform destroy` |
| Deploy changes | `git push origin main` |
| Get EC2 IP | `terraform output ec2_public_ip` |

---

## 🩺 13. Troubleshooting

| Problem | Likely cause and fix |
|---|---|
| Browser shows `ERR_CONNECTION_TIMED_OUT` | The instance IP changed after a stop/start, an inbound rule is missing in the security group, or the boot script is still running |
| Pods not ready | Check `tail -f /var/log/monitoring-setup.log` on the server |
| Prometheus targets show 403 | Make sure `kubelet-rbac.yaml` is applied |
| Dashboard not updating after a config change | Restart Prometheus and Grafana (see the CI/CD section) |
| Pipeline deploy step fails to connect | The `PROD_SERVER_IP` secret is outdated; update it with the current IP |

---

## 🗺️ 14. Roadmap

- [ ] Elastic IP managed by Terraform
- [ ] Switch AWS credentials to GitHub OIDC (no stored keys)
- [ ] Slack or email alert notifications
- [ ] Per-container metrics with cAdvisor
- [ ] Remote Terraform state in S3

---

<div align="center">

**Built by [Shubham](https://github.com/Shubhamx18)**

If this project helped you, consider giving it a ⭐

</div>
