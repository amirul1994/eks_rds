variable "oidc_provider_arn" {

}

variable "oidc_provider_url" {

}

variable "service_account_name" {

}

variable "service_account_namespace" {

}

variable "project_name" {

}

variable "environment" {
    
}

variable "attach_alb_controller_policy" {
    type = bool
    default = false
}

variable "attach_secrets_manager_policy" {
    type = bool
    default = false
}

variable "additional_policy_arns" {
    type = list(string)
    default = []
}