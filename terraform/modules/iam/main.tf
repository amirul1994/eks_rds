data "aws_iam_policy_document" "assume_role" {
    statement {
        actions = ["sts:AssumeRoleWithWebIdentity"]
        effect = "Allow"

        principals {
            type = "Federated"
            identifiers = [var.oidc_provider_arn]
        }

        condition {
            test = "StringEquals"
            variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"

            values = ["system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"]
        }
    }    
}

resource "aws_iam_role" "this" {
    name = "${var.project_name}-${var.environment}-${var.service_account_name}-irsa"

    assume_role_policy = data.aws_iam_policy_document.assume_role.json

    tags = {
        Name = "${var.project_name}-${var.environment}-${var.service_account_name}-irsa"
    }
}

data "aws_iam_policy" "alb_controller" {
  name = "AWSLoadBalancerControllerPolicy"
}


resource "aws_iam_role_policy_attachment" "alb_controller" {
  count      = var.attach_alb_controller_policy ? 1 : 0
  policy_arn = data.aws_iam_policy.alb_controller.arn
  role       = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "secrets_manager" {
    count = var.attach_secrets_manager_policy ? 1:0
    policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
    role = aws_iam_role.this.name
}