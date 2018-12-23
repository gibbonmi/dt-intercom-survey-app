data "aws_route53_zone" "main-site" {
  name = "mgdt1.com."
}

resource "aws_route53_record" "www-demo" {
  name = "${var.domain}.${data.aws_route53_zone.main-site.name}"
  type = "A"
  zone_id = "${data.aws_route53_zone.main-site.zone_id}"

  alias {
    evaluate_target_health = true
    name = "${module.ecs.alb_dns_name}"
    zone_id = "${module.ecs.alb_zone_id}"
  }
}