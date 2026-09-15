variable "vm_name" {
  type = string
}

variable "vm_image" {
  type = string
}

variable "vm_cpus" {
  type = number
}

variable "vm_memory" {
  type = string
}

variable "vm_disk" {
  type = string
}

variable "ssh_user" {
  type = string
}

variable "ssh_public_key_path" {
  type = string
}

variable "cloud_init_output_path" {
  type = string
}