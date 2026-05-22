variable "name" {
  type = string
}

variable "component" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "ec2_user" {
  type    = string
  default = "ec2-user"
}

variable "ec2_password" {
  type      = string
  sensitive = true
}

variable "associate_public_ip" {
  type    = bool
  default = false
}

variable "user_data" {
  type = string
}

variable "root_volume_size" {
  type    = number
  default = 20
}

variable "tags" {
  type    = map(string)
  default = {}
}
