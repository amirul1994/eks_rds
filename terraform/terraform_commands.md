```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the deployment
terraform apply -auto-approve

# Apply specific resource only
terraform apply -target=module.bastion.aws_instance.bastion

# Destroy infrastructure
terraform destroy

# Refresh state
terraform refresh

# Show state
terraform state list

# Show specific resource
terraform state show module.bastion.aws_instance.bastion

# Remove resource from state
terraform state rm module.eks.aws_eks_node_group.main

# Taint resource (force recreation)
terraform taint module.bastion.aws_instance.bastion

# Get output values
terraform output bastion_public_ip
terraform output -raw bastion_public_ip
terraform output -json backend_repository_url
```