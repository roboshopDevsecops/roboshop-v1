output "instances" {
  value = module.ec2
}

output "private_ips" {
  value = { for name, inst in module.ec2 : name => inst.private_ip }
}

output "public_ips" {
  value = { for name, inst in module.ec2 : name => inst.public_ip if inst.public_ip != "" }
}
