output "instance_id" {
    value = aws_instance.bastion.id
}

output "instance_public_ip" {
    value = aws_instance.bastion.public_ip
}

output "instance_private_ip" {
    value = aws_instance.bastion.private_ip
}