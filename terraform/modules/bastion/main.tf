resource "aws_iam_role" "bastion" {
    name = "${var.project_name}-${var.environment}-bastion-role"

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
        Name = "${var.project_name}-${var.environment}-bastion-role"
    }
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    role = aws_iam_role.bastion.name
}

resource "aws_iam_instance_profile" "bastion" {
    name = "${var.project_name}-${var.environment}-bastion-profile"

    role = aws_iam_role.bastion.name
} 

resource "aws_instance" "bastion" {
    ami = var.ami_id

    instance_type = var.instance_type 

    subnet_id = var.public_subnet_id 

    vpc_security_group_ids = [var.bastion_security_group_id]

    iam_instance_profile = aws_iam_instance_profile.bastion.name

    key_name = var.key_name

        user_data = <<-EOF
                #!/bin/bash
                set -ex
                
                # Update system
                apt-get update -y
                apt-get install -y openssh-server postgresql-client telnet curl wget
                
                # Configure SSH
                sed -i 's/^#Port 22/Port 22/' /etc/ssh/sshd_config
                sed -i 's/^#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config
                systemctl enable ssh
                systemctl restart ssh
                
                # Install SSM Agent from official deb package (Ubuntu 24.04 compatible)
                curl -o /tmp/amazon-ssm-agent.deb https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
                dpkg -i /tmp/amazon-ssm-agent.deb
                systemctl enable amazon-ssm-agent
                systemctl start amazon-ssm-agent
                
                # Wait for SSM to register
                sleep 10
                systemctl status amazon-ssm-agent --no-pager
                EOF 
    
    tags = {
        Name = "${var.project_name}-${var.environment}-bastion"
    }
}