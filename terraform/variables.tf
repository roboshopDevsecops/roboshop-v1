variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "env" {
  type = string
}

variable "network" {
  type = map(object({
    vpc_cidr = string
    subnets = object({
      public_subnets = list(string)
      app_subnets    = list(string)
      db_subnets     = list(string)
    })
    az = list(string)
  }))
}

variable "db_instances" {
  type = map(object({
    component           = string
    subnet_type         = string
    instance_type       = string
    subnet_index        = optional(number, 0)
    associate_public_ip = optional(bool, false)
    security_group      = string
  }))
}

variable "app_instances" {
  type = map(object({
    component           = string
    subnet_type         = string
    instance_type       = string
    subnet_index        = optional(number, 0)
    associate_public_ip = optional(bool, false)
    security_group      = string
  }))
}

variable "frontend_instances" {
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

variable "key_name" {
  type = string
}

variable "ec2_user" {
  type    = string
  default = "ec2-user"
}

variable "ec2_password" {
  type      = string
  sensitive = true
  default   = "DevOps321"
}

variable "ansible_repo_url" {
  type        = string
  description = "Git URL cloned by EC2 user-data (same monorepo)"
  default     = "https://github.com/raghudevopsb88/roboshop-v1.git"
}

variable "artifact_base_url" {
  type    = string
  default = "https://raw.githubusercontent.com/raghudevopsb88/roboshop-microservices-documentation/main/artifacts"
}

variable "ssh_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
