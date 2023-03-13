output "ip_v4" {
  value = equinix_metal_device.this.access_public_ipv4
}

output "ssh" {
  value = "ssh root@${equinix_metal_device.this.access_public_ipv4} -i ${module.key.name}.pem"
}
