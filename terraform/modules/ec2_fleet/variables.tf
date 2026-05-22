variable "env" {
  type = string
}

variable "tier" {
  type = string
}

variable "instances" {
  type = map(object({
    component           = string
    subnet_type         = string
    instance_type       = string
    subnet_index        = optional(number, 0)
    associate_public_ip = optional(bool, false)
    security_group      = string
  }))
}

variable "ami_id" {
  type = string
}

variable "ec2_user" {
  type = string
}

variable "ec2_password" {
  type      = string
  sensitive = true
}

variable "subnet_ids" {
  type = map(list(string))
}

variable "security_group_ids" {
  type = map(list(string))
}

variable "route53_zone_id" {
  type = string
}

variable "dns_zone" {
  type = string
}

variable "user_data_vars" {
  type = map(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
