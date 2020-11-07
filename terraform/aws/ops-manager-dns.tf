resource "aws_route53_zone" "hosted" {
  name = "${var.environment_name}.${var.hosted_zone}"
}

resource "aws_route53_record" "ops-manager" {
  name = "opsmanager.${aws_route53_zone.hosted.name}"

  zone_id = aws_route53_zone.hosted.zone_id
  type    = "A"
  ttl     = 300

  records = [aws_eip.ops-manager.public_ip]
}
