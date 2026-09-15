moved {
  from = local_file.cloud_init
  to   = module.compute.local_file.cloud_init
}

moved {
  from = terraform_data.multipass_vm
  to   = module.compute.terraform_data.multipass_vm
}