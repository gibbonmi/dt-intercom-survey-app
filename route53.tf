resource "aws_route53_record" "www-demo" {
  name = "${var.domain}"
  type = "CNAME"
  zone_id = "Z1E21SUNR3V3BD"
  ttl = "300"
  records = ["${module.ecs.}"]
}