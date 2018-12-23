variable "vpc_cidr" {
  description = "The CIDR block of the vpc"
}

variable "subnets_cidr" {
  type        = "list"
  description = "The CIDR block for the subnets"
}

variable "environment" {
  description = "The environment"
}

variable "region" {
  description = "The region to launch the bastion host"
}

variable "availability_zones" {
  type        = "list"
  description = "The az that the resources will be launched"
}