locals {
  production_availability_zones = ["us-east-1a", "us-east-1b"]
}

provider "aws" {
  region  = "${var.region}"
  shared_credentials_file = "~/.aws/credentials"
}

module "networking" {
  source = "./build/modules/networking"
  environment = "dt-intercom-survey-app-prod"
  vpc_cidr = "10.0.0.0/16"
  public_subnets_cidr = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidr = ["10.0.10.0/24", "10.0.20.0/24"]
  region = "us-east-1"
  availability_zones = "${local.production_availability_zones}"
}

module "ecs" {
  source              = "./build/modules/ecs"
  environment         = "production"
  vpc_id              = "${module.networking.vpc_id}"
  availability_zones  = "${local.production_availability_zones}"
  repository_name     = "dt-intercom-ces-survey-app"
  subnets_ids = ["${module.networking.private_subnets_id}"]
  public_subnet_ids         = ["${module.networking.public_subnets_id}"]
  security_groups_ids = [
    "${module.networking.security_groups_ids}"
  ]

}