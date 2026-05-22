resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.associate_public_ip

  user_data_base64 = base64encode(var.user_data)

  tags = merge(var.tags, {
    Name      = var.name
    Component = var.component
  })

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }
}
