# 🚀 EKS Terraform Deployment – Troubleshooting Guide

## 📋 Table of Contents
- [Node Group Issues](#1-node-group-issues)
- [Bastion SSH Issues](#2-bastion-ssh-issues)
- [ALB Controller Issues](#3-alb-controller-issues)
- [RDS Issues](#4-rds-issues)
- [VPC / Networking Issues](#5-vpc--networking-issues)
- [SSM Agent Issues](#6-ssm-agent-issues)
- [Terraform State Issues](#7-terraform-state-issues)
- [kubectl / Cluster Access](#8-kubectl--cluster-access)
- [CloudWatch Logs Issues](#9-cloudwatch-logs-issues)
- [ECR Issues](#10-ecr-issues)
- [Secrets Manager Issues](#11-secrets-manager-issues)

---

## 🔧 Troubleshooting Procedures

### 1. Node Group Issues

#### ❌ Error: `NodeCreationFailure: Instances failed to join the kubernetes cluster`

| Issue | Resolution |
|-------|------------|
| **VPC CNI addon missing** | Add `depends_on = [aws_eks_addon.vpc_cni]` to node group |
| **Wrong addon argument name** | Change `resolve_conflicts_on_create/update` to `resolve_conflicts` |
| **OIDC provider not found** | Construct OIDC ARN from cluster identity, remove data source |

**Fix Commands:**
```bash
# Check node group status
aws eks describe-nodegroup --cluster-name myapp-production --nodegroup-name main --query "nodegroup.statusReason" --output text

# Delete failed node group
aws eks delete-nodegroup --cluster-name myapp-production --nodegroup-name main

# Check VPC CNI addon
aws eks describe-addon --cluster-name myapp-production --addon-name vpc-cni --query "addon.status" --output text
```

**Terraform Fix:**
```hcl
resource "aws_eks_addon" "vpc_cni" {
    cluster_name                = aws_eks_cluster.this.name
    addon_name                  = "vpc-cni"
    addon_version               = "v1.18.3-eksbuild.3"
    resolve_conflicts           = "OVERWRITE"
    depends_on                  = [aws_eks_cluster.this]
}

resource "aws_eks_node_group" "main" {
    # ... config ...
    depends_on = [
        aws_iam_role_policy_attachment.node_worker,
        aws_iam_role_policy_attachment.node_cni,
        aws_iam_role_policy_attachment.node_ecr,
        aws_iam_role_policy_attachment.node_ssm,
        aws_eks_addon.vpc_cni   # ✅ Critical dependency
    ]
}
```

---

### 2. Bastion SSH Issues

#### ❌ Error: SSH Connection Hanging or Timing Out

| Issue | Resolution |
|-------|------------|
| **Security group blocking SSH** | Add inbound rule for port 22 from `0.0.0.0/0` |
| **No public IP** | Ensure `associate_public_ip_address = true` and public subnet |
| **SSH service not running** | Install openssh-server via user-data |
| **SSM Agent not registered** | Install SSM Agent from official `.deb` package |
| **Wrong key or user** | Use `ubuntu` as username and correct private key |

**Fix Commands:**
```bash
# Check security group
aws ec2 describe-security-groups --group-ids sg-xxxxxxxx --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\`]"

# Add SSH rule
aws ec2 authorize-security-group-ingress --group-id sg-xxxxxxxx --protocol tcp --port 22 --cidr 0.0.0.0/0

# Get bastion console output
aws ec2 get-console-output --instance-id i-xxxxxxxx --latest --output text | grep -i "error\|ssh"
```

**User-Data Fix:**
```bash
#!/bin/bash
set -ex
apt-get update -y
apt-get install -y openssh-server postgresql-client telnet curl wget
sed -i 's/^#Port 22/Port 22/' /etc/ssh/sshd_config
sed -i 's/^#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config
systemctl enable ssh
systemctl restart ssh
curl -o /tmp/amazon-ssm-agent.deb https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
dpkg -i /tmp/amazon-ssm-agent.deb
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
```

---

### 3. ALB Controller Issues

#### ❌ Error: `NoSuchEntity: Policy arn:aws:iam::aws:policy/AWSLoadBalancerControllerPolicy does not exist`

| Issue | Resolution |
|-------|------------|
| **Policy not found** | Create policy from official JSON |
| **Wrong ARN format** | Use `arn:aws:iam::<ACCOUNT_ID>:policy/` not `arn:aws:iam::aws:policy/` |
| **Missing permissions** | Use official JSON from GitHub |

**Fix Commands:**
```bash
# Download official policy
curl -o alb-controller-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

# Create policy
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerPolicy \
  --policy-document file://alb-controller-policy.json

# Verify policy exists
aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, 'LoadBalancer')]" --output table
```

**Terraform Fix:**
```hcl
# Use data source to reference existing policy
data "aws_iam_policy" "alb_controller" {
  name = "AWSLoadBalancerControllerPolicy"
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  policy_arn = data.aws_iam_policy.alb_controller.arn
  role       = aws_iam_role.this.name
}
```

---

### 4. RDS Issues

#### ❌ Error: `MasterUsername admin cannot be used as it is a reserved word`

**Fix:**
```bash
# Update secret with non-reserved username
aws secretsmanager update-secret \
  --secret-id myapp-production-rds-credentials \
  --secret-string '{"db_name":"mydb","username":"dbadmin","password":"YourStrongP@ssw0rd123!"}'
```

#### ❌ Error: `Cannot find version 17.3 for postgres`

**Fix:**
```hcl
# variables.tf
variable "rds_engine_version" {
  default = "16.3"   # ✅ Change from 17.5 to 16.3
}
```

#### ❌ Error: `Parameter group family mismatch`

**Fix:**
```hcl
# modules/rds/main.tf - Option 1: Match parameter group to version
resource "aws_db_parameter_group" "this" {
  family = "postgres17"   # ✅ Change from postgres15 to postgres17
}

# OR Option 2: Downgrade engine version
variable "rds_engine_version" {
  default = "15.6"   # ✅ Matches postgres15 parameter group
}
```

#### ❌ Error: `Route 53: Value is not a valid IPv4 address`

**Fix:**
```hcl
# modules/rds/main.tf - Change A record to CNAME
resource "aws_route53_record" "rds" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "db.${var.project_name}.internal"
  type    = "CNAME"   # ✅ Not "A" - RDS endpoint is a DNS name
  ttl     = 300
  records = [aws_db_instance.this.address]
}
```

#### ❌ Error: `log types 'slowquery', 'error' not supported`

**Fix:**
```hcl
# modules/rds/main.tf
enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]   # ✅ Remove slowquery and error
```

---

### 5. VPC / Networking Issues

#### ❌ Error: `Connect timeout on endpoint URL: "https://ec2.us-east-1.amazonaws.com/"`

| Issue | Resolution |
|-------|------------|
| **VPC endpoints missing** | Create VPC endpoints for private subnets |
| **NAT Gateway missing** | Ensure NAT Gateways exist and have routes |

**Fix:**
```hcl
# modules/vpc/main.tf - Add VPC endpoints
resource "aws_security_group" "endpoints" {
  vpc_id = aws_vpc.this.id
  name   = "${var.project_name}-${var.environment}-endpoints-sg"
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [local.first_private_subnet]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [local.first_private_subnet]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [local.first_private_subnet]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [local.first_private_subnet]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = aws_route_table.private[*].id
}
```

---

### 6. SSM Agent Issues

#### ❌ Error: `TargetNotConnected`

| Issue | Resolution |
|-------|------------|
| **SSM Agent not installed** | Install via user-data |
| **SSM Agent not running** | Start with `systemctl start amazon-ssm-agent` |
| **IAM role missing policy** | Attach `AmazonSSMManagedInstanceCore` |

**User-Data Fix:**
```bash
#!/bin/bash
curl -o /tmp/amazon-ssm-agent.deb https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
dpkg -i /tmp/amazon-ssm-agent.deb
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
```

**Check SSM Status:**
```bash
aws ssm describe-instance-information --filters "Key=InstanceIds,Values=i-xxxxxxxxxxxxxxxxx"
```

---

### 7. Terraform State Issues

#### ❌ Error: `Resource already exists` or `State lock stuck`

| Issue | Resolution |
|-------|------------|
| **Resource exists outside state** | Import or remove from state |
| **State lock stuck** | Use `terraform refresh` or delete lock file |
| **Tainted resources** | Use `terraform taint` and `terraform apply` |

**Commands:**
```bash
# Remove resource from state
terraform state rm module.eks.aws_eks_node_group.main

# Import existing resource
terraform import module.eks.aws_eks_node_group.main myapp-production/main

# Refresh state
terraform refresh

# Force recreation
terraform taint module.bastion.aws_instance.bastion
terraform apply
```

---

### 8. kubectl / Cluster Access

#### ❌ Error: `connection refused` or `timeout`

| Issue | Resolution |
|-------|------------|
| **Private cluster inaccessible** | Enable public endpoint temporarily |
| **kubectl not configured** | Run `aws eks update-kubeconfig` |
| **Nodes not showing** | Check node group status |

**Commands:**
```bash
# Enable public endpoint (temporary)
aws eks update-cluster-config \
  --name myapp-production \
  --resources-vpc-config endpointPublicAccess=true,publicAccessCidrs=["0.0.0.0/0"] \
  --region us-east-1

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name myapp-production

# Test access
kubectl get nodes

# Revert to private
aws eks update-cluster-config \
  --name myapp-production \
  --resources-vpc-config endpointPublicAccess=false,publicAccessCidrs=[] \
  --region us-east-1
```

---

### 9. CloudWatch Logs Issues

#### ❌ Error: `InvalidParameterException: Log groups starting with AWS/ are reserved`

**Fix:**
```hcl
# modules/eks/main.tf
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"   # ✅ Leading slash
  retention_in_days = 7
}
```

#### ❌ Error: `ResourceAlreadyExistsException`

**Fix:**
```bash
# Import existing log group
terraform import module.eks.aws_cloudwatch_log_group.eks /aws/eks/myapp-production/cluster

# OR delete and recreate
aws logs delete-log-group --log-group-name /aws/eks/myapp-production/cluster
```

---

### 10. ECR Issues

#### ❌ Error: Output blank or not showing

| Issue | Resolution |
|-------|------------|
| **Output not defined** | Add to `outputs.tf` |
| **Resources not applied** | Run `terraform apply` |

**Fix:**
```hcl
# outputs.tf
output "backend_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "frontend_repository_url" {
  value = aws_ecr_repository.frontend.repository_url
}
```

```bash
# Get URL
terraform output backend_repository_url
terraform output -raw backend_repository_url
```

---

### 11. Secrets Manager Issues

#### ❌ Error: `MasterUsername admin cannot be used`

**Fix:**
```bash
aws secretsmanager update-secret \
  --secret-id myapp-production-rds-credentials \
  --secret-string '{"db_name":"mydb","username":"dbadmin","password":"YourStrongP@ssw0rd123!"}'
```

#### ❌ Error: `InvalidParameterCombination: Cannot find version`

**Fix:**
```hcl
# variables.tf
variable "rds_engine_version" {
  default = "17.5"   # ✅ Valid version
}
```

---

## ✅ Quick Reference – Most Common Fixes

| Problem | Quick Fix |
|---------|-----------|
| **Node group fails** | Add `depends_on = [aws_eks_addon.vpc_cni]` |
| **SSH fails** | Check security group → Add SSH rule → Verify public IP |
| **ALB policy error** | Create policy from official JSON → Fix ARN |
| **RDS fails** | Use `dbadmin` not `admin` → Use PostgreSQL 16.3 |
| **RDS Route 53 error** | Use `CNAME` not `A` record |
| **VPC endpoint missing** | Add EC2, STS, ECR, S3 endpoints |
| **SSM not working** | Install SSM Agent via user-data |
| **kubectl fails** | Enable public endpoint → Run update-kubeconfig → Revert |
| **CloudWatch error** | Add leading slash to log group name |