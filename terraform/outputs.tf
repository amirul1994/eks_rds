output "bastion_ssm_command" {
    value = "aws ssm start-session --target ${module.bastion.instance_id}"
}

output "alb_controller_irsa_role_arn" {
    value = module.iam.iam_role_arn
}

output "backend_irsa_role_arn" {
    value = module.backend_irsa.iam_role_arn
}

output "backend_repository_url" {
    value = aws_ecr_repository.backend.repository_url 
}

output "frontend_repository_url" {
    value = aws_ecr_repository.frontend.repository_url 
}


output "backend_repository_name" {
    value = aws_ecr_repository.backend.name
} 

output "frontend_repository_name" {
    value = aws_ecr_repository.frontend.name
} 

output "vpc_id" {
    value = module.vpc.vpc_id
}

output "eks_cluster_name" {
    value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
    value = module.eks.cluster_endpoint
}

output "eks_cluster_ca_data" {
    value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_url" {
    value = module.eks.oidc_provider_url
}

output "bastion_public_ip" {
    value = module.bastion.instance_public_ip
}