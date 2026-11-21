.PHONY: help setup deploy destroy status logs port-forward reload-prometheus clean cluster-create cluster-delete

# ── Variables ──────────────────────────────────────────────────
CLUSTER_NAME  := overwatch-cluster
NAMESPACE     := monitoring
LOCAL_CONFIG  := k8s/kind/kind-cluster.yaml
EC2_CONFIG    := k8s/kind/kind-cluster-ec2.yaml

# ─────────────────────────────────────────────────────────────
## help: Show all available commands
help:
	@echo ""
	@echo "  Overwatch — Kubernetes Observability Stack"
	@echo "  ════════════════════════════════════════"
	@echo ""
	@echo "  LOCAL (Kind on your machine):"
	@echo "    make setup          Full setup — cluster + deploy"
	@echo "    make deploy         Deploy stack to existing cluster"
	@echo "    make status         Show all pods and services"
	@echo "    make port-forward   Forward ports to localhost"
	@echo "    make clean          Destroy everything"
	@echo ""
	@echo "  MONITORING:"
	@echo "    make logs-prometheus    Tail Prometheus logs"
	@echo "    make logs-grafana       Tail Grafana logs"
	@echo "    make logs-alertmanager  Tail Alertmanager logs"
	@echo "    make reload-prometheus  Reload config without restart"
	@echo ""
	@echo "  TERRAFORM (AWS EC2):"
	@echo "    make tf-init        Initialize Terraform"
	@echo "    make tf-plan        Preview EC2 infrastructure"
	@echo "    make tf-apply       Deploy to AWS EC2"
	@echo "    make tf-destroy     Destroy AWS infrastructure"
	@echo ""

# ─────────────────────────────────────────────────────────────
## setup: Create cluster + deploy full monitoring stack locally
setup: cluster-create deploy
	@echo ""
	@echo "  ✅ Stack is UP!"
	@echo ""
	@echo "  Prometheus   → http://localhost:19090"
	@echo "  Grafana      → http://localhost:13000  (admin / admin@123)"
	@echo "  Alertmanager → http://localhost:19093"
	@echo "  Blackbox     → http://localhost:19115"
	@echo ""

## cluster-create: Create the Kind cluster (local)
cluster-create:
	@echo "Creating Kind cluster..."
	kind create cluster --config $(LOCAL_CONFIG) --name $(CLUSTER_NAME)
	@echo "Cluster created!"
	kubectl cluster-info --context kind-$(CLUSTER_NAME)

## cluster-create-ec2: Create the Kind cluster (EC2 standard ports)
cluster-create-ec2:
	@echo "Creating Kind cluster for EC2..."
	kind create cluster --config $(EC2_CONFIG) --name $(CLUSTER_NAME)
	kubectl cluster-info --context kind-$(CLUSTER_NAME)

## cluster-delete: Delete the Kind cluster
cluster-delete:
	@echo "Deleting Kind cluster..."
	kind delete cluster --name $(CLUSTER_NAME)

## deploy: Deploy the full monitoring stack
deploy:
	@echo "Deploying monitoring stack..."
	kubectl apply -f k8s/namespace/
	@echo "Waiting for namespace..."
	sleep 3
	kubectl apply -f k8s/prometheus/
	kubectl apply -f k8s/alertmanager/
	kubectl apply -f k8s/grafana/
	kubectl apply -f k8s/grafana/finops-dashboard-configmap.yaml
	kubectl apply -f k8s/node-exporter/
	kubectl apply -f k8s/kube-state-metrics/
	kubectl apply -f k8s/blackbox-exporter/
	@echo "Waiting for all pods to be ready (up to 3 minutes)..."
	kubectl wait --for=condition=ready pod --all -n $(NAMESPACE) --timeout=180s
	@echo "✅ All pods are UP!"

## status: Show pod, service and PVC status
status:
	@echo ""
	@echo "═══ Pods ══════════════════════════════════"
	kubectl get pods -n $(NAMESPACE) -o wide
	@echo ""
	@echo "═══ Services ══════════════════════════════"
	kubectl get svc -n $(NAMESPACE)
	@echo ""
	@echo "═══ PVCs ══════════════════════════════════"
	kubectl get pvc -n $(NAMESPACE)
	@echo ""

## destroy: Remove all monitoring resources from cluster
destroy:
	@echo "Removing monitoring resources..."
	kubectl delete namespace $(NAMESPACE) --ignore-not-found
	@echo "Done."

## clean: Remove monitoring resources + delete Kind cluster
clean: destroy cluster-delete

# ─────────────────────────────────────────────────────────────
## logs-prometheus: Tail Prometheus logs
logs-prometheus:
	kubectl logs -f -l app=prometheus -n $(NAMESPACE)

## logs-grafana: Tail Grafana logs
logs-grafana:
	kubectl logs -f -l app=grafana -n $(NAMESPACE)

## logs-alertmanager: Tail Alertmanager logs
logs-alertmanager:
	kubectl logs -f -l app=alertmanager -n $(NAMESPACE)

## port-forward: Forward all ports to localhost
port-forward:
	@echo "Starting port-forward for all services..."
	@echo "  Prometheus   → http://localhost:19090"
	@echo "  Grafana      → http://localhost:13000"
	@echo "  Alertmanager → http://localhost:19093"
	kubectl port-forward svc/prometheus    19090:9090 -n $(NAMESPACE) &
	kubectl port-forward svc/grafana       13000:3000 -n $(NAMESPACE) &
	kubectl port-forward svc/alertmanager  19093:9093 -n $(NAMESPACE) &
	@echo "Press Ctrl+C to stop port forwarding"
	wait

## reload-prometheus: Reload Prometheus config without restart
reload-prometheus:
	@echo "Reloading Prometheus config..."
	kubectl port-forward svc/prometheus 19090:9090 -n $(NAMESPACE) &
	sleep 2
	curl -s -X POST http://localhost:19090/-/reload
	@echo "Config reloaded!"

# ─────────────────────────────────────────────────────────────
## tf-init: Initialize Terraform
tf-init:
	cd terraform-aws/prometheus-stack && terraform init

## tf-plan: Preview AWS infrastructure changes
tf-plan:
	cd terraform-aws/prometheus-stack && terraform plan -var-file=../vars/ec2.tfvars

## tf-apply: Deploy to AWS EC2
tf-apply:
	cd terraform-aws/prometheus-stack && terraform apply -var-file=../vars/ec2.tfvars

## tf-destroy: Destroy AWS infrastructure
tf-destroy:
	cd terraform-aws/prometheus-stack && terraform destroy -var-file=../vars/ec2.tfvars
