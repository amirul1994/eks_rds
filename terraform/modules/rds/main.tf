resource "aws_kms_key" "rds" {
    description = "KMS key for RDS encryption"
    #deletion_window_in_days = 30
    #enable_key_rotation = true

    tags = {
        Name = "${var.project_name}- ${var.environment}-rds-kms"
    }
}

resource "aws_kms_alias" "rds" {
    name = "alias/${var.project_name}-${var.environment}-rds"
    target_key_id = aws_kms_key.rds.key_id
} 

resource "aws_security_group" "rds" {
    vpc_id = var.vpc_id
    name = "${var.project_name}-${var.environment}-rds-sg"

    ingress {
        from_port = var.port 
        to_port = var.port 

        protocol = "tcp"
        security_groups = [var.bastion_security_group_id]
    }

    ingress {
        from_port = var.port
        to_port = var.port
        protocol = "tcp"
        security_groups = [var.eks_node_security_group_id]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.project_name}-${var.environment}-rds-sg"
    }
}


resource "aws_db_subnet_group" "this" {
    name = "${var.project_name}-${var.environment}-rds-subnet-group"

    subnet_ids = var.private_subnet_ids

    tags = {
        Name = "${var.project_name}-${var.environment}-rds-subnet-group"
    }
} 

resource "aws_db_parameter_group" "this" {
    family = var.engine == "postgres" ? "postgres17" : "mysql8.0"

    name = "${var.project_name}-${var.environment}-pg"

    tags = {
        Name = "${var.project_name}-${var.environment}-pg" 
    }
} 


data "aws_secretsmanager_secret" "rds_credentials" {
    name = "${var.project_name}-${var.environment}-rds-credentials"
}

data "aws_secretsmanager_secret_version" "rds_credentials" {
    secret_id = data.aws_secretsmanager_secret.rds_credentials.id
}

locals {
    rds_credentials = jsondecode(data.aws_secretsmanager_secret_version.rds_credentials.secret_string)
} 

resource "aws_db_instance" "this" {
    identifier = "${var.project_name}-${var.environment}-db"

    engine = var.engine

    engine_version = var.engine_version
    instance_class = var.instance_class

    allocated_storage = var.allocated_storage

    storage_type = var.storage_type

    storage_encrypted = true

    kms_key_id = aws_kms_key.rds.arn

    db_name = local.rds_credentials.db_name

    username = local.rds_credentials.username
    password = local.rds_credentials.password

    port = var.port 
    parameter_group_name = aws_db_parameter_group.this.name 
    vpc_security_group_ids = [aws_security_group.rds.id]
    db_subnet_group_name = aws_db_subnet_group.this.name

    multi_az = true

    backup_retention_period = 14

    backup_window = "03:00-04:00"
    maintenance_window = "Sun:04:00-Sun:05:00"

    enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

    skip_final_snapshot = false

    final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot-${formatdate("YYYYMMDDHHmmss", timestamp())}"

    deletion_protection = true

    tags = {
        Name = "${var.project_name}-${var.environment}-rds"
    }
}

resource "aws_route53_zone" "private" {
    name = "db.internal"

    vpc {
        vpc_id = var.vpc_id
    }

    tags = {
        Name = "${var.project_name}-${var.environment}-rds-zone"
    }
}

resource "aws_route53_record" "rds" {
    zone_id = aws_route53_zone.private.zone_id

    name = "postgres.db.internal"

    type = "CNAME"
    ttl = 300

    records = [aws_db_instance.this.address]
}