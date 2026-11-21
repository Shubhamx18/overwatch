# EC2 Instance Variables
region         = "ap-south-1"
ami_id         = "ami-0f58b397bc5c1f2e8"
instance_type  = "t3.medium"
key_name       = "shubham"
instance_count = 1
volume-size    = 30

# VPC — auto-discovered from default VPC in main.tf
vpc_id     = "default"
subnet_ids = ["default"]

# Tags
name        = "overwatch"
owner       = "devops-team"
environment = "dev"
cost_center = "monitoring"
application = "observability"

# Security Group — open ports
create_ingress_cidr      = true
ingress_cidr_from_port   = [22, 3000, 9090, 9093, 9115]
ingress_cidr_to_port     = [22, 3000, 9090, 9093, 9115]
ingress_cidr_protocol    = ["tcp", "tcp", "tcp", "tcp", "tcp"]
ingress_cidr_block       = ["0.0.0.0/0", "0.0.0.0/0", "0.0.0.0/0", "0.0.0.0/0", "0.0.0.0/0"]
ingress_cidr_description = ["SSH", "Grafana", "Prometheus", "Alertmanager", "Blackbox"]

# Egress — allow all outbound
create_egress_cidr    = true
egress_cidr_from_port = [0]
egress_cidr_to_port   = [0]
egress_cidr_protocol  = ["-1"]
egress_cidr_block     = ["0.0.0.0/0"]
