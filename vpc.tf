# VPC with 12 subnets to handle all the required hosts 
resource "aws_vpc" "deployment_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = var.tags
}

# Create Internet gateway for access to internet within VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.deployment_vpc.id
  tags = { Name = "${var.project_name}-igw" }
}

# Creating public subnets for load balancer and bastion server (450 hosts each)
resource "aws_subnet" "public_subnet" {
  for_each                = zipmap(var.azs, var.public_subnet_cidr)

  vpc_id                  = aws_vpc.deployment_vpc.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true 
  tags = { 
    Name = "${var.project_name}-public-${each.key}"
  }
}

# route table for public subnet
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.deployment_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public-rt-assoc" {
  # count          = length(aws_subnet.public_subnet)
  for_each       = aws_subnet.public_subnet
  
  # subnet_id      = aws_subnet.public_subnet[count.index].id
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public-rt.id
} 

# Create the elastic IP for the nat gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = { Name = "${var.project_name}-nat-eip" }
  depends_on = [ aws_internet_gateway.igw ]
}

# Create NAT Gateway
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet["us-east-1b"].id
  depends_on    = [aws_internet_gateway.igw]
  tags = { Name = "${var.project_name}-nat" }
}

# App private subnets (250 hosts each)
resource "aws_subnet" "app_subnet" {
  # count                   = length(var.private_subnet_cidr)
  for_each                = zipmap(var.azs, var.app_subnet_cidr)

  vpc_id                  = aws_vpc.deployment_vpc.id
  cidr_block              = each.value
  # availability_zone       = element(var.azs, count.index)
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = { 
    Name = "${var.project_name}-app-subnet-${each.key}"
  }
}

resource "aws_route_table" "app-subnet-rt" {
  vpc_id = aws_vpc.deployment_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = { Name = "${var.project_name}-app-subnet-rt" }
}

# Associate app subnet private route
resource "aws_route_table_association" "app_subnet_assoc" {
  for_each       = aws_subnet.app_subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app-subnet-rt.id
}

# Multi AZ RDS private subnet (680 hosts)
resource "aws_subnet" "rds_subnet" {
  for_each                = zipmap(var.azs, var.multi_az_rds_subnet_cidr)

  vpc_id                  = aws_vpc.deployment_vpc.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = { 
    Name = "${var.project_name}-rds-subnet-${each.key}"
  }
}

# RDS subnet group
resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = [for s in aws_subnet.rds_subnet : s.id]
  tags = {
    Name = "${var.project_name}-rds-subnet-group"
  }
}

# Oracle DB private subnet (254 hosts)
resource "aws_subnet" "oracle_db_subnet" {
  for_each                = zipmap(var.azs, var.oracle_db_subnet_cidr)

  vpc_id                  = aws_vpc.deployment_vpc.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = { 
    Name = "${var.project_name}-oracle-db-subnet-${each.key}"
  }
}

# Java application private subnet (50 hosts)
resource "aws_subnet" "java_app_subnet" {
  for_each                = zipmap(var.azs, var.java_app_subnet_cidr)

  vpc_id                  = aws_vpc.deployment_vpc.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = { 
    Name = "${var.project_name}-java-app-subnet-${each.key}"
  }
}

# Java application database private subnet (50 hosts)
resource "aws_subnet" "java_app_db_subnet" {
  for_each                = zipmap(var.azs, var.java_app_db_subnet_cidr)

  vpc_id                  = aws_vpc.deployment_vpc.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = { 
    Name = "${var.project_name}-java-db-subnet-${each.key}"
  }
}

# NACL for the VPC 
resource "aws_network_acl" "this" {
  vpc_id = aws_vpc.deployment_vpc.id
  tags   = var.tags
}

resource "aws_network_acl_rule" "allow_efs_inbound" {
  network_acl_id = aws_network_acl.this.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.deployment_vpc.cidr_block
  from_port      = 2049
  to_port        = 2049
} 

resource "aws_network_acl_rule" "allow_ssh_inbound" {
  network_acl_id = aws_network_acl.this.id
  rule_number    = 200
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.deployment_vpc.cidr_block
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "allow_rds_inbound" {
  network_acl_id = aws_network_acl.this.id
  rule_number    = 300
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.deployment_vpc.cidr_block
  from_port      = 3306
  to_port        = 3306
}

resource "aws_network_acl_rule" "allow_https_inbound" {
  network_acl_id = aws_network_acl.this.id
  rule_number    = 400
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.deployment_vpc.cidr_block
  from_port      = 443
  to_port        = 443 
}

resource "aws_network_acl_rule" "allow_http_inbound" {
  network_acl_id = aws_network_acl.this.id
  rule_number    = 500
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.deployment_vpc.cidr_block
  from_port      = 80
  to_port        = 80 
}

resource "aws_network_acl_rule" "allow_all_outbound" {
  network_acl_id = aws_network_acl.this.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = aws_vpc.deployment_vpc.cidr_block
  from_port      = 0  
  to_port        = 65535
}

# Bastion for debugging
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ecs_ami.id
  instance_type               = var.ec2_properties.instance_type
  subnet_id                   = aws_subnet.public_subnet["us-east-1a"].id
  key_name                    = aws_key_pair.this.key_name
  vpc_security_group_ids      = [ aws_security_group.public_sg.id ]
  associate_public_ip_address = true

  tags = {
    Name = "${var.project_name}-bastion-server"
  }
}