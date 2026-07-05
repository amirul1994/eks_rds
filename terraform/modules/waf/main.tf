resource "aws_wafv2_web_acl" "this" {
    name = "${var.project_name}-${var.environment}-waf"
    scope = var.scope

    default_action {
        allow {}
    }

    rule {
        name = "rate-limit"
        priority = 10
        action {
            block {}
        }
        statement {
            rate_based_statement {
                limit = var.rate_limit
                aggregate_key_type = "IP"
            }
        }
        visibility_config {
            cloudwatch_metrics_enabled = true
            metric_name = "rate-limit"
            sampled_requests_enabled = true
        }
    }

    rule {
        name = "aws-managed-common-rules"
        priority = 20
        override_action {
            none {}
        }
        statement {
            managed_rule_group_statement {
                name = "AWSManagedRulesCommonRuleSet"
                vendor_name = "AWS"
            }
        }
        visibility_config {
            cloudwatch_metrics_enabled = true
            metric_name = "aws-managed-common-rules"
            sampled_requests_enabled = true
        }
    }

    visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name = "waf-webacl"
        sampled_requests_enabled = true
    }

    tags = {
        Name = "${var.project_name}-${var.environment}-waf"
    }
}  