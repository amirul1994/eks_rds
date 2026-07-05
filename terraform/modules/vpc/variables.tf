variable "vpc_cidr" {}

variable "azs" {
    type = list(string)
} 

variable "public_subnet_cidrs" {
    type = list(string)
} 

variable "eks_private_subnet_cidrs" {
    type = list(string)
}

variable "rds_private_subnet_cidrs" {
    type = list(string)
}

variable "bastion_ssh_allowed_cidrs" {
    type = list(string)
}

variable "project_name" {

}

variable "environment" {
    
} 

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}