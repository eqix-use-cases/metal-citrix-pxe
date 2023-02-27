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
