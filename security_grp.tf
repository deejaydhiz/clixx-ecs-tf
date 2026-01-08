# Public SG (for bastion / web instances) - allows HTTP and SSH from internet
resource "aws_security_group" "public_sg" {
  name        = "${var.project_name}-public-sg"
  description = "Allow SSH/HTTP from Internet"
  vpc_id      = aws_vpc.deployment_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-public-sg" }
}

# App/Private SG - instances in private subnets (e.g. app servers)
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for application servers (private subnets)"
  vpc_id      = aws_vpc.deployment_vpc.id

  # Allow SSH from admin CIDR (optional). For now only allow SSH from public SG (bastion).
  ingress {
    description     = "SSH from bastion and admin"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  # Allow HTTP from public SG
  ingress {
    description = "HTTP from the public subnet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-app-sg" }
}

# RDS SG - allows DB traffic from app_sg
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow DB access from app servers"
  vpc_id      = aws_vpc.deployment_vpc.id

  ingress {
    description     = "DB access from App servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}

# EFS SG - allow NFS from app servers (or other instances in private subnets)
resource "aws_security_group" "efs_sg" {
  name        = "${var.project_name}-efs-sg"
  description = "Allow NFS (EFS) traffic from app servers"
  vpc_id      = aws_vpc.deployment_vpc.id

  ingress {
    description     = "NFS from App servers"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-efs-sg" }
}

