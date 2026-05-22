resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.env}-roboshop-vpc"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.subnets["public_subnets"])
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnets["public_subnets"][count.index]
  availability_zone       = var.az[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.env}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "app" {
  count             = length(var.subnets["app_subnets"])
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnets["app_subnets"][count.index]
  availability_zone = var.az[count.index]

  tags = {
    Name = "${var.env}-app-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "db" {
  count             = length(var.subnets["db_subnets"])
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnets["db_subnets"][count.index]
  availability_zone = var.az[count.index]

  tags = {
    Name = "${var.env}-db-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.env}-igw"
  }
}

resource "aws_route_table" "public" {
  count  = length(var.subnets["public_subnets"])
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.env}-public-rt-${count.index + 1}"
  }
}

resource "aws_route_table" "app" {
  count  = length(var.subnets["app_subnets"])
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.env}-app-rt-${count.index + 1}"
  }
}

resource "aws_route_table" "db" {
  count  = length(var.subnets["db_subnets"])
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.env}-db-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.subnets["public_subnets"])
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}

resource "aws_route_table_association" "app" {
  count          = length(var.subnets["app_subnets"])
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

resource "aws_route_table_association" "db" {
  count          = length(var.subnets["db_subnets"])
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db[count.index].id
}

resource "aws_route" "public_internet" {
  count                  = length(var.subnets["public_subnets"])
  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_eip" "nat" {
  count  = length(var.subnets["public_subnets"])
  domain = "vpc"

  tags = {
    Name = "${var.env}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "nat" {
  count         = length(var.subnets["public_subnets"])
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.env}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route" "app_nat" {
  count                  = length(var.subnets["app_subnets"])
  route_table_id         = aws_route_table.app[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[count.index].id
}

resource "aws_route" "db_nat" {
  count                  = length(var.subnets["db_subnets"])
  route_table_id         = aws_route_table.db[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[count.index % length(aws_nat_gateway.nat)].id
}
