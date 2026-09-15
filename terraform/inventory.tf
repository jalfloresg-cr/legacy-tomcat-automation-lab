resource "local_file" "ansible_inventory" {
  filename = "${path.root}/../ansible/inventory/hosts.ini"

  content = templatefile(
    "${path.root}/templates/hosts.ini.tftpl",
    {
      server_name     = module.compute.name
      host            = module.compute.host
      ssh_user        = module.compute.ssh_user
      ssh_port        = module.compute.ssh_port
      ssh_private_key = pathexpand(var.ssh_private_key_path)
    }
  )
}