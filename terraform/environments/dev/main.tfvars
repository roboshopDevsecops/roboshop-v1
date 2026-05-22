env        = "dev"
aws_region = "us-east-1"

ami_id       = "ami-0220d79f3f480ecf5"
ec2_user     = "ec2-user"
ec2_password = "DevOps321"

ansible_repo_url = "https://github.com/roboshopDevsecops/roboshop-v1.git"

network = {
  dev = {
    vpc_cidr = "10.20.0.0/24"
    subnets = {
      public_subnets = ["10.20.0.0/27", "10.20.0.32/27"]
      db_subnets     = ["10.20.0.64/27", "10.20.0.96/27"]
      app_subnets    = ["10.20.0.128/26", "10.20.0.192/26"]
    }
    az = ["us-east-1a", "us-east-1b"]
  }
}

# Tier 1 — databases and broker (boot first)
db_instances = {
  mysql = {
    component      = "mysql"
    subnet_type    = "db"
    subnet_index   = 0
    instance_type  = "t3.small"
    security_group = "db"
  }
  mongodb = {
    component      = "mongodb"
    subnet_type    = "db"
    subnet_index   = 1
    instance_type  = "t3.small"
    security_group = "db"
  }
  valkey = {
    component      = "valkey"
    subnet_type    = "db"
    subnet_index   = 0
    instance_type  = "t3.small"
    security_group = "db"
  }
  rabbitmq = {
    component      = "rabbitmq"
    subnet_type    = "db"
    subnet_index   = 1
    instance_type  = "t3.small"
    security_group = "db"
  }
}

# Tier 2 — application microservices (boot after DB tier)
app_instances = {
  catalogue = {
    component      = "catalogue"
    subnet_type    = "app"
    subnet_index   = 0
    instance_type  = "t3.small"
    security_group = "app"
  }
  user = {
    component      = "user"
    subnet_type    = "app"
    subnet_index   = 1
    instance_type  = "t3.small"
    security_group = "app"
  }
  cart = {
    component      = "cart"
    subnet_type    = "app"
    subnet_index   = 0
    instance_type  = "t3.small"
    security_group = "app"
  }
  shipping = {
    component      = "shipping"
    subnet_type    = "app"
    subnet_index   = 1
    instance_type  = "t3.small"
    security_group = "app"
  }
  payment = {
    component      = "payment"
    subnet_type    = "app"
    subnet_index   = 0
    instance_type  = "t3.small"
    security_group = "app"
  }
  notification = {
    component      = "notification"
    subnet_type    = "app"
    subnet_index   = 1
    instance_type  = "t3.small"
    security_group = "app"
  }
  orders = {
    component      = "orders"
    subnet_type    = "app"
    subnet_index   = 0
    instance_type  = "t3.small"
    security_group = "app"
  }
  ratings = {
    component      = "ratings"
    subnet_type    = "app"
    subnet_index   = 1
    instance_type  = "t3.small"
    security_group = "app"
  }
}

# Tier 3 — frontend (boot last)
frontend_instances = {
  frontend = {
    component           = "frontend"
    subnet_type         = "public"
    subnet_index        = 0
    instance_type       = "t3.small"
    associate_public_ip = true
    security_group      = "frontend"
  }
}

tags = {
  Project = "roboshop"
}
