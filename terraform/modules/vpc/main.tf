resource "aws_vpc" "this" {
    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true
    enable_dns_support = true

    tags = {
        Name = "${var.project_name}-${var.environment}-vpc"
    }
}

resource "aws_internet_gateway" "this" {
    vpc_id = aws_vpc.this.id

    tags = {
        Name = "${var.project_name}-${var.environment}-igw"
    }
}

resource "aws_subnet" "public" {
    count = length(var.public_subnet_cidrs)
    vpc_id = aws_vpc.this.id

    cidr_block = var.public_subnet_cidrs[count.index]

    availability_zone = var.azs[count.index]

    map_public_ip_on_launch = true

    tags = {
        Name = "${var.project_name}-${var.environment}-public-${var.azs[count.index]}"
        "kubernetes.io/role/elb" = "1"
    }
}

resource "aws_subnet" "eks_private" {
    count = length(var.eks_private_subnet_cidrs)
    vpc_id = aws_vpc.this.id
    cidr_block = var.eks_private_subnet_cidrs[count.index]

    availability_zone = var.azs[count.index]

    tags = {
        Name = "${var.project_name}-${var.environment}-eks-private-${var.azs[count.index]}"
        "kubernetes.io/role/internal-elb" = "1"
    }
}

resource "aws_subnet" "rds_private" {
    count = length(var.rds_private_subnet_cidrs)
    vpc_id = aws_vpc.this.id

    cidr_block = var.rds_private_subnet_cidrs[count.index]

    availability_zone = var.azs[count.index]

    tags = {
        Name = "${var.project_name}-${var.environment}-rds-private-${var.azs[count.index]}"
    }
}

resource "aws_eip" "nat" {
    count = length(var.azs)
    
    tags = {
        Name = "${var.project_name}-${var.environment}-nat-ip-${var.azs[count.index]}"
    }
}

resource "aws_nat_gateway" "this" {
    count = length(var.azs)
    allocation_id = aws_eip.nat[count.index].id

    subnet_id = aws_subnet.public[count.index].id

    tags = {
        Name = "${var.project_name}-${var.environment}-nat-${var.azs[count.index]}"
    }

    depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.this.id

    route {
        cidr_block = "0.0.0.0/0"

        gateway_id = aws_internet_gateway.this.id
    }

    tags = {
        Name = "${var.project_name}-${var.environment}-public-rt"
    }
}

resource "aws_route_table_association" "public" {
        count = length(var.public_subnet_cidrs)

        subnet_id = aws_subnet.public[count.index].id

        route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
    count = length(var.azs)

    vpc_id = aws_vpc.this.id

    route {
        cidr_block = "0.0.0.0/0"

        nat_gateway_id = aws_nat_gateway.this[count.index].id
    }

    tags = {
        Name = "${var.project_name}-${var.environment}-private-rt-${var.azs[count.index]}"
    }
}

resource "aws_route_table_association" "eks_private" {
    count = length(var.eks_private_subnet_cidrs)

    subnet_id = aws_subnet.eks_private[count.index].id

    route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "rds_private" {
    count = length(var.rds_private_subnet_cidrs)
    subnet_id = aws_subnet.rds_private[count.index].id
    route_table_id = aws_route_table.private[count.index].id
}

# -----------------------------------------------------------------
# VPC Endpoints for Private Subnet Communication
# -----------------------------------------------------------------

# Security group for VPC endpoints (allows HTTPS from VPC CIDR)
resource "aws_security_group" "endpoints" {
  vpc_id = aws_vpc.this.id
  name   = "${var.project_name}-${var.environment}-endpoints-sg"
  description = "Security group for VPC endpoints"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-endpoints-sg"
  }
}

# Get the first private subnet ID (for the endpoint ENI)
locals {
  first_private_subnet = element(aws_subnet.eks_private[*].id, 0)
}

# Interface endpoint for EC2 API
resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [local.first_private_subnet]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-endpoint"
  }
}

# Interface endpoint for STS
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [local.first_private_subnet]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-${var.environment}-sts-endpoint"
  }
}

# Interface endpoint for ECR API
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [local.first_private_subnet]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-${var.environment}-ecr-api-endpoint"
  }
}

# Interface endpoint for ECR DKR
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [local.first_private_subnet]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-${var.environment}-ecr-dkr-endpoint"
  }
}

# Gateway endpoint for S3 (needed for ECR image layers)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = aws_route_table.private[*].id

  tags = {
    Name = "${var.project_name}-${var.environment}-s3-endpoint"
  }
}

resource "aws_security_group" "bastion" {
    vpc_id = aws_vpc.this.id

    name = "${var.project_name}-${var.environment}-bastion-sg"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = var.bastion_ssh_allowed_cidrs
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"

        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.project_name}-${var.environment}-bastion-sg"
    }
}