terraform {
    required_version = ">= 1.10"

    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.0"
        }

        kubernetes = {
            source = "hashicorp/kubernetes"
            version = "~> 2.23"
        }

        helm = {
            source = "hashicorp/helm"
            version = "~> 2.9"
        }

        tls = {
            source = "hashicorp/tls"
            version = "~> 4.0"
        } 

        local = {
            source = "hashicorp/local"
            version = "~> 2.4"
        }
    }
}

provider "aws" {
    region = var.aws_region

    default_tags {
        tags = {
            Environment = var.environment 
            Project = var.project_name
            ManagedBy = "Terraform"
        }
    }
}