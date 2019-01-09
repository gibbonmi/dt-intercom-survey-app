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

module "code_pipeline" {
  source = "./build/modules/code_pipeline"
  repository_url = "${module.ecs.repository_url}"
  region = "${var.region}"
  ecs_service_name = "${module.ecs.service_name}"
  ecs_cluster_name = "${module.ecs.cluster_name}"
  run_task_subnet_id = "${module.networking.public_subnets_id[0]}"
  run_task_security_group_ids = ["${module.networking.security_groups_ids}", "${module.ecs.security_group_id}"]
}

data "aws_route53_zone" "main-site" {
  name = "mgdt1.com."
}

resource "aws_route53_record" "www-demo" {
  name = "demo.${data.aws_route53_zone.main-site.name}"
  type = "CNAME"
  zone_id = "${data.aws_route53_zone.main-site.zone_id}"
  records = ["${module.ecs.alb_dns_name}"]
  ttl = "300"
}