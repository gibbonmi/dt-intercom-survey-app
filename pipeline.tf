module "code_pipeline" {
  source = "./build/modules/code_pipeline"
  repository_url = "${module.ecs.repository_url}"
  region = "${var.region}"
  ecs_service_name = "${module.ecs.service_name}"
  ecs_cluster_name = "${module.ecs.cluster_name}"
  run_task_subnet_id = "${module.networking.subnets_id[0]}"
  run_task_security_group_ids = ["${module.networking.security_groups_ids}", "${module.ecs.security_group_id}"]
}