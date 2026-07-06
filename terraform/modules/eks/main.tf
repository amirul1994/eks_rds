resource "aws_iam_role" "cluster" {
    name = "${var.cluster_name}-cluster-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"

        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "eks.amazonaws.com"
            }
        }]
    })

    tags = {
        Name = "${var.cluster_name}-cluster-role" 
    }
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "vpc_resource_controller" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
    role = aws_iam_role.cluster.name
}

resource "aws_eks_cluster" "this" {
    name = var.cluster_name

    role_arn = aws_iam_role.cluster.arn

    enabled_cluster_log_types = var.cluster_log_types

    version = var.cluster_version

    vpc_config {
        subnet_ids = var.private_subnet_ids
        endpoint_private_access = true
        endpoint_public_access = false
        security_group_ids = [aws_security_group.cluster.id]
    }

    tags = {
        Name = var.cluster_name
    }

    depends_on = [
        aws_iam_role_policy_attachment.cluster_policy,
        aws_iam_role_policy_attachment.vpc_resource_controller
    ]
}

resource "aws_eks_addon" "vpc_cni" {
    cluster_name = aws_eks_cluster.this.name
    addon_name = "vpc-cni"
    addon_version = "v1.18.3-eksbuild.3"
    resolve_conflicts = "OVERWRITE"
    

    depends_on = [
        aws_eks_cluster.this
    ]
}

resource "aws_security_group" "cluster" {
    vpc_id = var.vpc_id

    name = "${var.cluster_name}-cluster-sg"

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.cluster_name}-cluster-sg"
    }
}

resource "aws_security_group_rule" "cluster_ingress_bastion" {
    type = "ingress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    source_security_group_id = var.bastion_security_group_id
    security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group" "node" {
    vpc_id = var.vpc_id

    name = "${var.cluster_name}-node-sg"

    ingress {
        from_port = 1025
        to_port = 65535
        protocol = "tcp"

        security_groups = [aws_security_group.cluster.id]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        security_groups = [var.bastion_security_group_id]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.cluster_name}-node-sg"
    }
}

resource "aws_iam_role" "node" {
    name = "${var.cluster_name}-node-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "ec2.amazonaws.com"
            }
        }]
    })
    
    tags = {
        Name = "${var.cluster_name}-node-role"
    } 
}

resource "aws_iam_role_policy_attachment" "node_worker" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    role = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_cni" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    role = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    role = aws_iam_role.node.name
} 

resource "aws_iam_role_policy_attachment" "node_ssm" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    role = aws_iam_role.node.name
}

resource "aws_eks_node_group" "main" {
    cluster_name = aws_eks_cluster.this.name

    node_group_name = "main"

    node_role_arn = aws_iam_role.node.arn

    subnet_ids = var.private_subnet_ids

    scaling_config {
        desired_size = var.node_desired_size
        min_size = var.node_min_size
        max_size = var.node_max_size
    }

    instance_types = [var.node_instance_type]

    ami_type = "AL2_x86_64"

    remote_access {
        ec2_ssh_key = var.node_ssh_key_name
        source_security_group_ids = [aws_security_group.node.id]
    }

    disk_size = var.node_volume_size

    tags = {
        Name = "${var.cluster_name}-node-group"
    }

    depends_on = [
        aws_iam_role_policy_attachment.node_worker,
        aws_iam_role_policy_attachment.node_cni,
        aws_iam_role_policy_attachment.node_ecr,
        aws_iam_role_policy_attachment.node_ssm,
        aws_eks_addon.vpc_cni
    ]
}


data "aws_caller_identity" "current" {

}

locals {
    oidc_issuer_url = aws_eks_cluster.this.identity[0].oidc[0].issuer
    oidc_provider   = replace(local.oidc_issuer_url, "https://", "")
    oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"
}

resource "aws_cloudwatch_log_group" "eks" {
    name = "/aws/eks/${var.cluster_name}/cluster"
    retention_in_days = 7

    tags = {
        Name = "${var.cluster_name}-cluster-logs"
    }
}