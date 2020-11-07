locals {
  stable_config_concourse = {
    concourse_url= aws_route53_record.concourse.name
  }
}

output "stable_config_concourse" {
  value     = jsonencode(local.stable_config_concourse)
  sensitive = true
}
