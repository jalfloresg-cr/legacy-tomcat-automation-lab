variable "vm_name" {
  type    = string
  default = "legacy-tomcat"
}

variable "vm_image" {
  type    = string
  default = "24.04"
}

variable "vm_cpus" {
  type    = number
  default = 2
}

variable "vm_memory" {
  type    = string
  default = "2G"
}

variable "vm_disk" {
  type    = string
  default = "10G"
}

variable "ssh_user" {
  type    = string
  default = "ansible"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519"
}