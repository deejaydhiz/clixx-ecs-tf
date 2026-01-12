data "aws_route53_zone" "mydns" {
  provider     = aws.management
  name         = "deji-stack.com"
  private_zone = false
}

data "aws_ami" "ecs_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_name]
  }

  owners = [ var.accounts["dev"], var.accounts["mgmt"] ]
}

data "aws_ecr_repository" "clixx_repo" {
  name = "clixx-repository"
}

data "aws_ecr_image" "clixx_image" {
  repository_name = data.aws_ecr_repository.clixx_repo.name
  image_tag       = "latest" 
}

data "aws_ssm_parameter" "db_pass" {
  name = "clixxdb-pass"
}

data "aws_iam_instance_profile" "ecs" {
  name = var.ec2_properties["iam_instance_profile"]
}