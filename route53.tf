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