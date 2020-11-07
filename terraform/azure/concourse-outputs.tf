locals {
  stable_config_concourse = {
    concourse_url = "${azurerm_dns_a_record.concourse.name}.${azurerm_dns_a_record.concourse.zone_name}"
  }
}

output "stable_config_concourse" {
  value     = jsonencode(local.stable_config_concourse)
  sensitive = true
}