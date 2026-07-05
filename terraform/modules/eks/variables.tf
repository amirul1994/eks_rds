variable "cluster_name" {

}

variable "cluster_version" {
    default = "1.31"
}

variable "vpc_id" {

}

variable "private_subnet_ids" {
    type = list(string)
}

variable "node_instance_type" {

}

variable "node_desired_size" {
    type = number
}

variable "node_min_size" {
    type = number
}

variable "node_max_size" {
    type = number
}

variable "node_volume_size" {
    type = number
}

variable "node_ssh_key_name" {

}



variable "bastion_security_group_id" {

}

variable "project_name" {

}

variable "environment" {
    
}

variable "cluster_log_types" {
  description = "List of EKS control plane log types to enable (api, audit, authenticator, controllerManager, scheduler)"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}