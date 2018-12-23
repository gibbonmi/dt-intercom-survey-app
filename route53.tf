resource "aws_route53_delegation_set" "main" {
  reference_name = "DynDNS"
}

resource "aws_route53_zone" "primary_route" {
  name = "${var.domain}"
  delegation_set_id = "${aws_route53_delegation_set.main.id}"
}

resource "aws_route53_record" "www-test" {
  name = "www.${var.domain}"
  type = "A"
  zone_id = "${aws_route53_zone.primary_route.id}"

  alias {
    evaluate_target_health = true
    name = "${module.ecs.alb_dns_name}"
    zone_id = "${module.ecs.alb_zone_id}"
  }
}