resource "aws_ecr_repository" "backend" {
    name = "${var.project_name}-${var.environment}-${var.backend_repo_name}"

    image_tag_mutability = "MUTABLE"

    image_scanning_configuration {
        scan_on_push = true
    }

    tags = {
        Name = "${var.project_name}-${var.environment}-${var.backend_repo_name}"
        Component = "backend"
    }
}


resource "aws_ecr_repository" "frontend" {
    name = "${var.project_name}-${var.environment}-${var.frontend_repo_name}"

    image_tag_mutability = "MUTABLE"

    image_scanning_configuration {
        scan_on_push = true
    }

    tags = {
        Name = "${var.project_name}-${var.environment}-${var.frontend_repo_name}"
        Component = "frontend"
    }
}


module "vpc" {
    source = "./modules/vpc"
    aws_region = var.aws_region
    vpc_cidr = var.vpc_cidr
    azs = var.azs

    public_subnet_cidrs = var.public_subnet_cidrs
    eks_private_subnet_cidrs = var.eks_private_subnet_cidrs
    rds_private_subnet_cidrs = var.rds_private_subnet_cidrs

    bastion_ssh_allowed_cidrs = var.bastion_ssh_allowed_cidrs

    project_name = var.project_name

    environment = var.environment
}

module "eks" {
    source = "./modules/eks"

    cluster_name = "${var.project_name}-${var.environment}"
    cluster_version = var.eks_cluster_version

    vpc_id = module.vpc.vpc_id

    private_subnet_ids = module.vpc.eks_private_subnet_ids

    node_instance_type = var.eks_node_instance_type
    node_desired_size = var.eks_node_desired_size
    node_min_size = var.eks_node_min_size
    node_max_size = var.eks_node_max_size
    node_volume_size = var.eks_node_volume_size
    
    node_ssh_key_name = var.ssh_key_name
    
    bastion_security_group_id = module.vpc.bastion_security_group_id

    project_name = var.project_name
    environment = var.environment
}

module "iam" {
    source = "./modules/iam"
    oidc_provider_arn = module.eks.oidc_provider_arn
    oidc_provider_url = module.eks.oidc_provider_url
    
    service_account_name = var.alb_controller_service_account_name
    service_account_namespace = var.alb_controller_service_account_namespace

    attach_alb_controller_policy = true
    attach_secrets_manager_policy = false

    project_name = var.project_name
    environment = var.environment
}

module "backend_irsa" {
    source = "./modules/iam"

    oidc_provider_arn = module.eks.oidc_provider_arn
    oidc_provider_url = module.eks.oidc_provider_url

    service_account_name = "backend-sa"
    service_account_namespace = "default"

    attach_alb_controller_policy = false
    attach_secrets_manager_policy = true

    project_name = var.project_name
    environment = var.environment
}

module "rds" {
    source = "./modules/rds"
    vpc_id = module.vpc.vpc_id

    private_subnet_ids = module.vpc.rds_private_subnet_ids

    bastion_security_group_id = module.vpc.bastion_security_group_id
    eks_node_security_group_id = module.eks.node_security_group_id

    engine = var.rds_engine
    engine_version = var.rds_engine_version

    instance_class = var.rds_instance_class

    allocated_storage = var.rds_allocated_storage
    storage_type = var.rds_storage_type

    port = var.rds_engine == "postgres" ? 5432 : 3306

    project_name = var.project_name
    environment = var.environment
} 

module "bastion" {
    source = "./modules/bastion"

    vpc_id = module.vpc.vpc_id
    public_subnet_id = module.vpc.public_subnet_ids[0]

    bastion_security_group_id = module.vpc.bastion_security_group_id

    instance_type = var.bastion_instance_type

    ami_id = var.bastion_ami_id

    key_name = var.ssh_key_name

    project_name = var.project_name

    environment = var.environment
}

module "waf" {
    source = "./modules/waf"
    scope = var.waf_scope
    rate_limit = var.waf_rate_limit

    project_name = var.project_name
    environment = var.environment
}

provider "kubernetes" {
    host = module.eks.cluster_endpoint

    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command = "aws"
        args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
}

provider "helm" {
    kubernetes {
        host = module.eks.cluster_endpoint

        cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

        exec {
            api_version = "client.authentication.k8s.io/v1beta1"
            command = "aws"

            args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
        }
    }
}