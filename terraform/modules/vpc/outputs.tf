output "vpc_id" {
    value = aws_vpc.this.id 
}

output "public_subnet_ids" {
    value = aws_subnet.public[*].id
}

output "eks_private_subnet_ids" {
    value = aws_subnet.eks_private[*].id
}

output "rds_private_subnet_ids" {
    value = aws_subnet.rds_private[*].id
}

output "bastion_security_group_id" {
    value = aws_security_group.bastion.id
}