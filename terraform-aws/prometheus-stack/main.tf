terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment below to use S3 remote state (recommended for teams)
  # First create the S3 bucket and DynamoDB table manually, then enable this:
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "prometheus-stack/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region
}

# ── Auto-discover default VPC and its subnets ─────────────────────────────────
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

module "ec2" {
  source             = "../modules/ec2"
  region             = var.region
  ami_id             = var.ami_id
  instance_type      = var.instance_type
  key_name           = var.key_name
  instance_count     = var.instance_count
  subnet_ids         = data.aws_subnets.default.ids
  name               = var.name
  environment        = var.environment
  owner              = var.owner
  cost_center        = var.cost_center
  application        = var.application
  security_group_ids = module.security-group.security_group_ids
  volume-size        = var.volume-size
}

module "security-group" {
  source      = "../modules/security-group"
  region      = var.region
  tags        = var.tags
  name        = var.name
  environment = var.environment
  owner       = var.owner
  cost_center = var.cost_center
  application = var.application
  vpc_id      = data.aws_vpc.default.id

  ingress_cidr_from_port   = var.ingress_cidr_from_port
  ingress_cidr_to_port     = var.ingress_cidr_to_port
  ingress_cidr_protocol    = var.ingress_cidr_protocol
  ingress_cidr_block       = var.ingress_cidr_block
  ingress_cidr_description = var.ingress_cidr_description
  create_ingress_cidr      = var.create_ingress_cidr

  egress_cidr_from_port = var.egress_cidr_from_port
  egress_cidr_to_port   = var.egress_cidr_to_port
  egress_cidr_protocol  = var.egress_cidr_protocol
  egress_cidr_block     = var.egress_cidr_block
  create_egress_cidr    = var.create_egress_cidr
}

# ── Outputs ───────────────────────────────────────────────────────────────────
output "ec2_public_ip" {
  description = "Public IP of the Overwatch EC2 instance"
  value       = module.ec2.instance_public_ip[0]
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://${module.ec2.instance_public_ip[0]}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${module.ec2.instance_public_ip[0]}:9090"
}

output "alertmanager_url" {
  description = "Alertmanager URL"
  value       = "http://${module.ec2.instance_public_ip[0]}:9093"
}

output "ssh_command" {
  description = "SSH command to connect to EC2"
  value       = "ssh -i shubham.pem ubuntu@${module.ec2.instance_public_ip[0]}"
}
