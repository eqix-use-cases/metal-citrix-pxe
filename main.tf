resource "random_pet" "this" {
  length = 3
}

module "key" {
  source     = "git::github.com/andrewpopa/terraform-metal-project-ssh-key"
  project_id = var.project_id
}

data "template_file" "this" {
  template = file("bootstrap/boot.sh")
}

resource "equinix_metal_vlan" "this" {
  description = "VLAN in Dallas"
  metro       = var.metro
  vxlan       = var.vlanid
  project_id  = var.project_id
}

resource "equinix_metal_device_network_type" "this" {
  device_id = equinix_metal_device.this.id
  type      = "hybrid"
}

resource "equinix_metal_port_vlan_attachment" "this" {
  device_id = equinix_metal_device_network_type.this.id
  port_name = "bond0"
  vlan_vnid = equinix_metal_vlan.this.vxlan
}

resource "equinix_metal_device" "this" {
  hostname            = random_pet.this.id
  plan                = var.plan
  metro               = var.metro
  operating_system    = var.operating_system
  billing_cycle       = "hourly"
  project_id          = var.project_id
  project_ssh_key_ids = [module.key.id]
  user_data           = data.template_file.this.rendered
}
