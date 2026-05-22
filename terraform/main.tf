module "vpc" {
  for_each = var.network
  source   = "./modules/vpc"

  env      = var.env
  vpc_cidr = each.value.vpc_cidr
  subnets  = each.value.subnets
  az       = each.value.az
}

locals {
  network_key = var.env
  vpc         = module.vpc[local.network_key]

  subnet_ids = {
    public = local.vpc.public_subnet_ids
    app    = local.vpc.app_subnet_ids
    db     = local.vpc.db_subnet_ids
  }

  dns_zone = "${var.env}.roboshop.internal"

  service_hosts = {
    mysql        = "mysql.${local.dns_zone}"
    mongodb      = "mongodb.${local.dns_zone}"
    valkey       = "valkey.${local.dns_zone}"
    rabbitmq     = "rabbitmq.${local.dns_zone}"
    catalogue    = "catalogue.${local.dns_zone}"
    user         = "user.${local.dns_zone}"
    cart         = "cart.${local.dns_zone}"
    shipping     = "shipping.${local.dns_zone}"
    payment      = "payment.${local.dns_zone}"
    notification = "notification.${local.dns_zone}"
    orders       = "orders.${local.dns_zone}"
    ratings      = "ratings.${local.dns_zone}"
    frontend     = "frontend.${local.dns_zone}"
  }

  user_data_common = {
    ansible_repo_url  = var.ansible_repo_url
    artifact_base_url = var.artifact_base_url
    env               = var.env
    ec2_user          = var.ec2_user
    ec2_password      = var.ec2_password
    mysql_host        = local.service_hosts.mysql
    mongodb_host      = local.service_hosts.mongodb
    valkey_host       = local.service_hosts.valkey
    rabbitmq_host     = local.service_hosts.rabbitmq
    catalogue_host    = local.service_hosts.catalogue
    user_host         = local.service_hosts.user
    cart_host         = local.service_hosts.cart
    shipping_host     = local.service_hosts.shipping
    payment_host      = local.service_hosts.payment
    notification_host = local.service_hosts.notification
    orders_host       = local.service_hosts.orders
    ratings_host      = local.service_hosts.ratings
    frontend_host     = local.service_hosts.frontend
    wait_hosts_db     = "${local.service_hosts.mysql} ${local.service_hosts.mongodb} ${local.service_hosts.valkey} ${local.service_hosts.rabbitmq}"
    wait_hosts_app    = "${local.service_hosts.catalogue} ${local.service_hosts.user} ${local.service_hosts.cart} ${local.service_hosts.shipping} ${local.service_hosts.payment} ${local.service_hosts.notification} ${local.service_hosts.orders} ${local.service_hosts.ratings}"
  }
}

resource "aws_route53_zone" "private" {
  name = local.dns_zone

  vpc {
    vpc_id = local.vpc.vpc_id
  }

  tags = {
    Name = "${var.env}-roboshop-private-zone"
  }
}

resource "aws_security_group" "frontend" {
  name        = "${var.env}-roboshop-frontend-sg"
  description = "Frontend / Nginx"
  vpc_id      = local.vpc.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-frontend-sg"
  }
}

resource "aws_security_group" "app" {
  name        = "${var.env}-roboshop-app-sg"
  description = "RoboShop application microservices"
  vpc_id      = local.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  ingress {
    description = "Microservice ports from VPC"
    from_port   = 8000
    to_port     = 8099
    protocol    = "tcp"
    cidr_blocks = [local.vpc.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-app-sg"
  }
}

resource "aws_security_group" "db" {
  name        = "${var.env}-roboshop-db-sg"
  description = "RoboShop databases and message broker"
  vpc_id      = local.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  ingress {
    description = "MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [local.vpc.vpc_cidr]
  }

  ingress {
    description = "MongoDB"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [local.vpc.vpc_cidr]
  }

  ingress {
    description = "Valkey (Redis)"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [local.vpc.vpc_cidr]
  }

  ingress {
    description = "RabbitMQ AMQP"
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = [local.vpc.vpc_cidr]
  }

  ingress {
    description = "RabbitMQ management"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = [local.vpc.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-db-sg"
  }
}

locals {
  security_group_ids = {
    frontend = [aws_security_group.frontend.id]
    app      = [aws_security_group.app.id]
    db       = [aws_security_group.db.id]
  }
}

# Tier 1: databases and message broker
module "ec2_db" {
  source = "./modules/ec2_fleet"

  env                = var.env
  tier               = "db"
  instances          = var.db_instances
  ami_id             = var.ami_id
  ec2_user           = var.ec2_user
  ec2_password       = var.ec2_password
  subnet_ids         = local.subnet_ids
  security_group_ids = local.security_group_ids
  route53_zone_id    = aws_route53_zone.private.zone_id
  dns_zone           = local.dns_zone
  tags               = var.tags
  user_data_vars     = merge(local.user_data_common, { wait_hosts = "" })
}

# Tier 2: application microservices (after DB tier is up)
module "ec2_app" {
  source = "./modules/ec2_fleet"

  env                = var.env
  tier               = "app"
  instances          = var.app_instances
  ami_id             = var.ami_id
  ec2_user           = var.ec2_user
  ec2_password       = var.ec2_password
  subnet_ids         = local.subnet_ids
  security_group_ids = local.security_group_ids
  route53_zone_id    = aws_route53_zone.private.zone_id
  dns_zone           = local.dns_zone
  tags               = var.tags
  user_data_vars     = merge(local.user_data_common, { wait_hosts = local.user_data_common.wait_hosts_db })

  depends_on = [module.ec2_db]
}

# Tier 3: frontend (after app tier is up)
module "ec2_frontend" {
  source = "./modules/ec2_fleet"

  env                = var.env
  tier               = "frontend"
  instances          = var.frontend_instances
  ami_id             = var.ami_id
  ec2_user           = var.ec2_user
  ec2_password       = var.ec2_password
  subnet_ids         = local.subnet_ids
  security_group_ids = local.security_group_ids
  route53_zone_id    = aws_route53_zone.private.zone_id
  dns_zone           = local.dns_zone
  tags               = var.tags
  user_data_vars = merge(local.user_data_common, {
    wait_hosts = "${local.user_data_common.wait_hosts_db} ${local.user_data_common.wait_hosts_app}"
  })

  depends_on = [module.ec2_app]
}

locals {
  all_instances = merge(
    module.ec2_db.instances,
    module.ec2_app.instances,
    module.ec2_frontend.instances,
  )
}
