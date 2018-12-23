output "vpc_id" {
  value = "${aws_vpc.vpc.id}"
}

output "subnets_id" {
  value = ["${aws_subnet.subnet.*.id}"]
}
output "default_sg_id" {
  value = "${aws_security_group.default.id}"
}

output "security_groups_ids" {
  value = ["${aws_security_group.default.id}"]
}