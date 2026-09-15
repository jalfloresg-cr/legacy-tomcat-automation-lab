output "name" {
  value = var.vm_name
}

output "host" {
  value = data.external.multipass_info.result.host
}

output "ssh_user" {
  value = var.ssh_user
}

output "ssh_port" {
  value = 22
}