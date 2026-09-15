locals {
  ssh_public_key = trimspace(
    file(pathexpand(var.ssh_public_key_path))
  )
}

resource "local_file" "cloud_init" {
  filename = var.cloud_init_output_path

  content = templatefile(
    "${path.module}/templates/cloud-init.yaml.tftpl",
    {
      ssh_user       = var.ssh_user
      ssh_public_key = local.ssh_public_key
    }
  )
}

resource "terraform_data" "multipass_vm" {

  triggers_replace = [
    var.vm_name,
    var.vm_image,
    tostring(var.vm_cpus),
    var.vm_memory,
    var.vm_disk,
    local_file.cloud_init.content_sha256
  ]

  provisioner "local-exec" {
    command = <<-EOT
      multipass launch ${var.vm_image} \
        --name ${var.vm_name} \
        --cpus ${var.vm_cpus} \
        --memory ${var.vm_memory} \
        --disk ${var.vm_disk} \
        --cloud-init ${local_file.cloud_init.filename}
    EOT
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue

    command = <<-EOT
      multipass delete --purge ${self.triggers_replace[0]}
    EOT
  }

  depends_on = [
    local_file.cloud_init
  ]
}

data "external" "multipass_info" {
  program = [
    "python3",
    "${path.module}/scripts/multipass_info.py"
  ]

  query = {
    name = var.vm_name
  }

  depends_on = [
    terraform_data.multipass_vm
  ]
}