variable "aws_region" {
    description = "AWS region"
    type = string
    default = "us-east-1"
}

variable "environment" {
    description = "Environment name"
    type = string
    default = "production" 
}

variable "project_name" {
    description = "Project name for resource naming"
    type = string
    default = "myapp"
}


variable "ssh_key_name" {
    type = string
    default = "myapp-production-key"
}

variable "vpc_cidr" {
    type = string
    default = "10.0.0.0/16"
}

variable "azs" {
    type = list(string)
    default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
    type = list(string)
    default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "eks_private_subnet_cidrs" {
    type = list(string)
    default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "rds_private_subnet_cidrs" {
    type = list(string)
    default = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "eks_cluster_version" {
    type = string
    default = "1.31"
}

variable "eks_node_instance_type" {
    type = string
    default = "t3.medium"
}

variable "eks_node_desired_size" {
    type = number
    default = 1
}

variable "eks_node_min_size" {
    type = number
    default = 1
} 

variable "eks_node_max_size" {
    type = number
    default = 2
}

variable "eks_node_volume_size" {
    type = number
    default = 30
} 

variable "rds_instance_class" {
    type = string
    default = "db.t3.medium"
}

variable "rds_allocated_storage" {
    type = number
    default = 30
}

variable "rds_storage_type" {
    type = string
    default = "gp3"
} 

variable "rds_engine" {
    type = string
    default = "postgres"
} 

variable "rds_engine_version" {
    type = string
    default = "17.5" 
}

variable "bastion_instance_type" {
    type = string
    default = "t2.small"
}

variable "bastion_ami_id" {
    description = "AMI ID for bastion (Ubuntu 24.04 amd64, us-east-1)"
    type = string
    default = "ami-0a02a779008fa3b99"
}

variable "bastion_ssh_allowed_cidrs" {
    description = "cidrs allowed to ssh to bastion"
    type = list(string)
    default = ["0.0.0.0/0"] 
}

variable "waf_scope" {
    type = string
    default = "REGIONAL"
}

variable "waf_rate_limit" {
    type = number
    default = 2000
}

variable "alb_controller_service_account_name" {
    type = string
    default = "aws-load-balancer-controller"
}

variable "alb_controller_service_account_namespace" {
    type = string
    default = "kube-system"
}

variable "backend_repo_name" {
    type = string
    default = "backend"
} 

variable "frontend_repo_name" {
    type = string
    default = "frontend"
}