variable "vpc_id" {} 

variable "private_subnet_ids" {
    type = list(string)
}

variable "bastion_security_group_id" {

}

variable "eks_node_security_group_id" {

}

variable "engine" {

}

variable "engine_version" {

}

variable "instance_class" {

}

variable "allocated_storage" {
    type = number
} 

variable "storage_type" {
    default = "gp3"
} 

variable "port" {
    type = number
}

variable "project_name" {

}

variable "environment" {
    
}