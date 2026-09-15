module "compute" {
  source = "./modules/compute/multipass"

  vm_name   = var.vm_name
  vm_image  = var.vm_image
  vm_cpus   = var.vm_cpus
  vm_memory = var.vm_memory
  vm_disk   = var.vm_disk

  ssh_user            = var.ssh_user
  ssh_public_key_path = var.ssh_public_key_path

  cloud_init_output_path = "${path.root}/cloud-init.generated.yaml"
}