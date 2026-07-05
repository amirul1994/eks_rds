**Prerequisites & Setup**

```bash
# Configure AWS CLI
aws configure

# Get AWS account ID
aws sts get-caller-identity --query Account --output text
```
**SSH Key Pair**

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/myapp-key -C "myapp-production"

# Import key pair to AWS
aws ec2 import-key-pair \
  --key-name "myapp-production-key" \
  --public-key-material fileb://~/.ssh/myapp-key.pub \
  --region us-east-1

# Verify key pair exists
aws ec2 describe-key-pairs --key-name myapp-production-key --region us-east-1
```

**S3 Bucket (Terraform State Backend)**

```bash
BUCKET_NAME="amirul-eks-rds"

# Create bucket
aws s3api create-bucket --bucket $BUCKET_NAME --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Block public access
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

**Secrets Manager (RDS Credentials)**

```bash
# Create secret with db_name, username, password
aws secretsmanager create-secret \
  --name "myapp-production-rds-credentials" \
  --secret-string '{"db_name":"mydb","username":"dbadmin","password":"YourStrongP@ssw0rd123!"}' \
  --region us-east-1

# Update secret
aws secretsmanager update-secret \
  --secret-id myapp-production-rds-credentials \
  --secret-string '{"db_name":"mydb","username":"dbadmin","password":"passwordwithuppercaselowercasenumberspecialcharacter"}'

# Get secret value
aws secretsmanager get-secret-value \
  --secret-id myapp-production-rds-credentials \
  --query 'SecretString' \
  --output text | jq .
```

**ALB Controller Policy**

```bash
# Download the official policy
curl -o alb-controller-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

# Create the policy
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerPolicy \
  --policy-document file://alb-controller-policy.json

# Verify policy exists
aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, 'LoadBalancer')]" --output table
```

**EKS Cluster Operations**

```bash
# Describe cluster
aws eks describe-cluster --name myapp-production --query "cluster.status" --output text

# Get cluster endpoint
aws eks describe-cluster --name myapp-production --query "cluster.endpoint" --output text

# Check cluster health
aws eks describe-cluster --name myapp-production --query "cluster.health" --output json | jq .

# List node groups
aws eks list-nodegroups --cluster-name myapp-production

# Describe node group
aws eks describe-nodegroup \
  --cluster-name myapp-production \
  --nodegroup-name main \
  --query "nodegroup.{Status:status, StatusReason:statusReason, Health:health}" \
  --output json | jq .

# Delete node group
aws eks delete-nodegroup --cluster-name myapp-production --nodegroup-name main

# Wait for node group deletion
aws eks wait nodegroup-active --cluster-name myapp-production --nodegroup-name main 2>/dev/null || echo "Node group deleted"

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name myapp-production

# Enable public endpoint access (for testing)
aws eks update-cluster-config \
  --name myapp-production \
  --resources-vpc-config endpointPublicAccess=true,publicAccessCidrs=["0.0.0.0/0"] \
  --region us-east-1

# Revert to private endpoint only
aws eks update-cluster-config \
  --name myapp-production \
  --resources-vpc-config endpointPublicAccess=false,publicAccessCidrs=[] \
  --region us-east-1
```

**EKS Add-ons**

```bash
# Check VPC CNI addon status
aws eks describe-addon --cluster-name myapp-production --addon-name vpc-cni --query "addon.status" --output text

# List addons
aws eks list-addons --cluster-name myapp-production

# Install CloudWatch Observability addon
aws eks create-addon \
  --addon-name amazon-cloudwatch-observability \
  --cluster-name myapp-production \
  --service-account-role-arn arn:aws:iam::654654294624:role/AmazonCloudWatchObservabilityRole
``` 

**EC2/Bastion Host**

```bash
# Get bastion public IP
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=myapp-production-bastion" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text

# Check bastion state
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=myapp-production-bastion" \
  --query "Reservations[0].Instances[0].State.Name" \
  --output text

# Get bastion instance ID
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=myapp-production-bastion" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text

# Get bastion console output
aws ec2 get-console-output --instance-id i-0158c6dab34181f9c --latest --output text | tail -50

# Terminate instances
aws ec2 terminate-instances --instance-ids i-xxxxxxxxxxxxxxxxx

# List all bastion instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=myapp-production-bastion" \
  --query "Reservations[*].Instances[*].{ID:InstanceId, State:State.Name, SubnetId:SubnetId, PublicIp:PublicIpAddress}" \
  --output table
``` 

**Security Groups**

```bash
# Get bastion security group ID
BASTION_SG=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=myapp-production-bastion" \
  --query "Reservations[0].Instances[0].SecurityGroups[0].GroupId" \
  --output text)

# Check SSH inbound rule
aws ec2 describe-security-groups --group-ids $BASTION_SG --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\`]" --output json | jq .

# Add SSH inbound rule
aws ec2 authorize-security-group-ingress \
  --group-id $BASTION_SG \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# Check cluster security group
CLUSTER_SG=$(aws eks describe-cluster --name myapp-production --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)
aws ec2 describe-security-groups --group-ids $CLUSTER_SG --query "SecurityGroups[0].IpPermissions" --output json | jq .
```

**Networking/VPC**

```bash
# Get VPC ID
VPC_ID=$(aws eks describe-cluster --name myapp-production --query "cluster.resourcesVpcConfig.vpcId" --output text)

# List NAT gateways
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$VPC_ID" \
  --query "NatGateways[*].{ID:NatGatewayId, State:State, SubnetId:SubnetId}" \
  --output table

# Check route tables
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "RouteTables[*].{ID:RouteTableId, VpcId:VpcId, Routes:Routes}" \
  --output table

# Check EIPs
aws ec2 describe-addresses \
  --filters "Name=tag:Name,Values=myapp-production-nat-eip-us-east-1a" \
  --query "Addresses[*].{AllocationId:AllocationId, PublicIp:PublicIp}" \
  --output table

# Check subnet routes
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=subnet-xxxxxxxxxxxxxxxxx" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0']" \
  --output table
```

**RDS Database**

```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier myapp-production-db \
  --query "DBInstances[0].DBInstanceStatus" \
  --output text

# Get RDS endpoint
aws rds describe-db-instances \
  --db-instance-identifier myapp-production-db \
  --query "DBInstances[0].Endpoint.{Address:Address, Port:Port}" \
  --output json | jq .

# Check RDS events
aws rds describe-events \
  --source-identifier myapp-production-db \
  --source-type db-instance \
  --max-items 10 \
  --query "Events[*].{Message:Message, Date:Date}" \
  --output table

# Delete RDS
aws rds delete-db-instance \
  --db-instance-identifier myapp-production-db \
  --skip-final-snapshot
```

**CloudWatch Logs**

```bash
# List log groups
aws logs describe-log-groups --log-group-name-prefix /aws/eks/myapp-production

# Tail logs
aws logs tail /aws/eks/myapp-production/cluster --since 10m --filter-pattern "error"

# Delete log group
aws logs delete-log-group --log-group-name /aws/eks/myapp-production/cluster
```

**IAM/IRSA**

```bash
# List attached role policies
aws iam list-attached-role-policies --role-name myapp-production-node-role --query "AttachedPolicies[*].PolicyName" --output table

# Get role ARN
aws iam get-role --role-name myapp-production-node-role --query "Role.Arn" --output text

# Check OIDC provider
aws iam list-open-id-connect-providers
```

**SSM (Systems Manager)**

```bash
# Check SSM agent status
aws ssm describe-instance-information --filters "Key=InstanceIds,Values=i-xxxxxxxxxxxxxxxxx"

# Start SSM session
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx

# If SSM fails with TargetNotConnected, the agent is not running
```

**ECR**

```bash
# List repositories
aws ecr describe-repositories --repository-names myapp-production-backend myapp-production-frontend

# Get login password
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 654654294624.dkr.ecr.us-east-1.amazonaws.com
```