/* Cloudwatch log group */
resource "aws_cloudwatch_log_group" "intercom-survey-app" {
  name = "intercom-survey-app"

  tags {
    Environment = "${var.environment}"
    Application = "Intercom-Survey-App"
  }
}

/* ecr repository */
resource "aws_ecr_repository" "intercom-survey-app" {
  name = "${var.repository_name}"
}

resource "aws_ecs_cluster" "cluster" {
  name = "${var.environment}-ecs-cluster"
}

/* ecs task definition */
data "template_file" "web_task" {
  template = "${file("${path.module}/tasks/web_task_definition.json")}"

  vars {
    image = "${aws_ecr_repository.intercom-survey-app.repository_url}"
    log_group = "${aws_cloudwatch_log_group.intercom-survey-app.name}"
  }
}

resource "aws_ecs_task_definition" "web" {
  family = "${var.environment}_web"
  container_definitions = "${data.template_file.web_task.rendered}"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = "256"
  memory = "512"
  execution_role_arn = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn = "${aws_iam_role.ecs_execution_role.arn}"
}

/* alb */
resource "random_id" "target_group_sufix" {
  byte_length = 2
}

resource "aws_alb_target_group" "alb_target_group" {
  name = "${var.environment}-alb-target-group-${random_id.target_group_sufix.hex}"
  port = 3002
  protocol = "HTTP"
  vpc_id = "${var.vpc_id}"
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }
}

/* alb security group */
resource "aws_security_group" "web_inbound_sg" {
  name = "${var.environment}-web-inbound-sg"
  description = "Allow HTTPS from Anywhere into ALB"
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port = 443
    protocol = "tcp"
    to_port = 443
  cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.environment}-web-inbound-sg"
  }
}

resource "aws_alb" "alb-intercom-survey-app" {
  name = "${var.environment}-alb-survey-app"
  subnets = ["${var.subnets_ids}"]
  security_groups = ["${var.security_groups_ids}", "${aws_security_group.web_inbound_sg.id}"]

  tags {
    Name = "${var.environment}-alb-intercom-survey-app"
    Environment = "${var.environment}"
  }
}

resource "aws_alb_listener" "intercom-survey-app" {
  "default_action" {
    type = "forward"
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
  }
  load_balancer_arn = "${aws_alb.alb-intercom-survey-app.arn}"
  port = 443
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2016-08"
  certificate_arn = "arn:aws:acm:us-east-1:406709384314:certificate/26cd79dc-b3f9-4b48-8a89-7a5e358063bf"
}

/* iam service role */
data "aws_iam_policy_document" "ecs_service_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ecs.amazonaws.com", "ec2.amazonaws.com"]
      type = "Service"
    }
  }
}

resource "aws_iam_role" "ecs_role" {
  name = "ecs_role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_service_role.json}"
}

data "aws_iam_policy_document" "ecs_service_policy" {
  statement {
    effect = "Allow"
    resources = ["*"]
    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "ec2:Describe*",
      "ec2:AuthorizeSecurityGroupIngress"
    ]
  }
}

resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name = "ecs_service_role_policy"
  policy = "${data.aws_iam_policy_document.ecs_service_policy.json}"
  role = "${aws_iam_role.ecs_role.id}"
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_task_execution_role"
  assume_role_policy = "${file("${path.module}/policies/ecs-task-execution-role.json")}"
}

resource "aws_iam_role_policy" "ecs_execution_role_policy" {
  name = "ecs_execution_role_policy"
  policy = "${file("${path.module}/policies/ecs-execution-role-policy.json")}"
  role = "${aws_iam_role.ecs_execution_role.id}"
}

/*** ECS service ***/

/* security group for ecs */
resource "aws_security_group" "ecs_service" {
  vpc_id = "${var.vpc_id}"
  name = "${var.environment}-ecs-service-sg"
  description = "Allow egress from container"

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8
    protocol = "icmp"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 3002
    protocol = "tcp"
    to_port = 3002
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "${var.environment}-ecs-service-sg"
    Environment = "${var.environment}"
  }
}

data "aws_ecs_task_definition" "web" {
  task_definition = "${aws_ecs_task_definition.web.family}"
  depends_on = ["aws_ecs_task_definition.web"]
}

resource "aws_ecs_service" "web" {
  name = "${var.environment}-web"
  task_definition = "${aws_ecs_task_definition.web.family}:${max("${aws_ecs_task_definition.web.revision}", "${data.aws_ecs_task_definition.web.revision}")}"
  desired_count = 2
  launch_type = "FARGATE"
  cluster = "${aws_ecs_cluster.cluster.id}"
  depends_on = ["aws_iam_role_policy.ecs_service_role_policy", "aws_alb_target_group.alb_target_group"]

  network_configuration {
    security_groups = ["${var.security_groups_ids}", "${aws_security_group.ecs_service.id}"]
    subnets = ["${var.subnets_ids}"]
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
    container_name = "web"
    container_port = "3002"
  }
}

/*** autoscaling ***/

resource "aws_iam_role" "ecs_autoscale_role" {
  name = "${var.environment}_ecs_autoscale_role"
  assume_role_policy = "${file("${path.module}/policies/ecs-autoscale-role.json")}"
}

resource "aws_iam_role_policy" "ecs_autoscale_role_policy" {
  name = "ecs_autoscale_role_policy"
  policy = "${file("${path.module}/policies/ecs-autoscale-role-policy.json")}"
  role = "${aws_iam_role.ecs_autoscale_role.id}"
}

resource "aws_appautoscaling_target" "target" {
  service_namespace = "ecs"
  resource_id = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  role_arn = "${aws_iam_role.ecs_autoscale_role.arn}"
  min_capacity = 2
  max_capacity = 4
}

resource "aws_appautoscaling_policy" "up" {
  name                    = "${var.environment}_scale_up"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.web.name}"
  scalable_dimension      = "ecs:service:DesiredCount"


  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = 1
    }
  }

  depends_on = ["aws_appautoscaling_target.target"]
}

resource "aws_appautoscaling_policy" "down" {
  name                    = "${var.environment}_scale_down"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.web.name}"
  scalable_dimension      = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = -1
    }
  }

  depends_on = ["aws_appautoscaling_target.target"]
}

/* metric used for auto scale */
resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
  alarm_name = "${var.environment}_openjobs_web_cpu_utilization_high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/ECS"
  period = "60"
  statistic = "Maximum"
  threshold = "85"

  dimensions {
    ClusterName = "${aws_ecs_cluster.cluster.name}"
    ServiceName = "${aws_ecs_service.web.name}"
  }

  alarm_actions = ["${aws_appautoscaling_policy.up.arn}"]
  ok_actions = ["${aws_appautoscaling_policy.down.arn}"]
}