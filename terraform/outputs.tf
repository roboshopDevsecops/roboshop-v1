output "vpc_id" {
  value = module.vpc[var.env].vpc_id
}

output "frontend_public_ip" {
  value = module.ec2_frontend.instances["frontend"].public_ip
}

output "private_dns_zone" {
  value = aws_route53_zone.private.name
}

output "db_private_ips" {
  value = module.ec2_db.private_ips
}

output "app_private_ips" {
  value = module.ec2_app.private_ips
}

output "instance_private_ips" {
  value = merge(
    module.ec2_db.private_ips,
    module.ec2_app.private_ips,
    module.ec2_frontend.private_ips,
  )
}

output "instance_public_ips" {
  value = merge(
    module.ec2_db.public_ips,
    module.ec2_app.public_ips,
    module.ec2_frontend.public_ips,
  )
}

output "instance_dns_names" {
  value = {
    for name, _ in local.all_instances : name => "${name}.${local.dns_zone}"
  }
}
