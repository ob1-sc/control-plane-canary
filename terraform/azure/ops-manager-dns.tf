resource "azurerm_dns_zone" "hosted" {
  name                = "${var.environment_name}.${var.hosted_zone}"
  resource_group_name = azurerm_resource_group.platform.name
}

resource "azurerm_dns_a_record" "ops-manager" {
  name                = "opsmanager"
  zone_name           = azurerm_dns_zone.hosted.name
  resource_group_name = azurerm_dns_zone.hosted.resource_group_name
  ttl                 = "60"
  records             = [azurerm_public_ip.ops-manager.ip_address]

  tags = merge(
    var.tags,
    { name = "opsmanager.${var.environment_name}" },
  )
}
