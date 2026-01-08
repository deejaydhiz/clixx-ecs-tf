variable "env" {
  description = "The environment for the deployment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "uat", "prod", "auto"], var.env)
    error_message = "The env variable must be one of the following: dev, test, uat, prod."
  }
}

variable "accounts" {
    type = map(string)
    default = {
        dev  = "186769093804"
        uat  = "961424819918"
        auto = "055081916963"
        mgmt = "651974166650"
    }
}

variable "rds_instance_properties" {
  description = "A map of RDS instance properties"
  type        = map(string)
  default = {
    username            = "admin"
    instance_class      = "db.t4g.micro"
    publicly_accessible = false
    snapshot_identifier = "clixxwordpressdb"
    skip_final_snapshot = true
  }
} 

variable "aws_region" {
  description = "This is the AWS region to build the resources"
  type = string
  default = "us-east-1"
}

variable project_name {
  description = "The project name"
  type = string
  default = "clixx"
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default = {
    Name        = "Clixx-Terraform-Deployment"
    stackTeam   = "stackcloud14"
    OwnerEmail  = "stackawsdeij@gmail.com"
    Environment = "dev"
    Project     = "clixx-web-deployment"
    CostCenter  = "cc1234"
    Application = "clixx-website"
  }
}

variable "ec2_properties" {
  description = "A map of EC2 instance properties"
  type        = map(string)
  default = {
    name                    = "clixx-web"
    instance_type           = "t3.micro"
    key_name                = "clixx-kp"
    iam_instance_profile    = "IAM_instance_profile"
  }
}

variable "ami_name" {
  description = "Name of the ECS AMI"
  type        = string
  default     = "stack14-ecs_ami"
}

variable "public_key_path" {
  description = "Path to the public key file (.pub) used to create the AWS key pair."
  type        = string
  default     = "./clixx-kp.pub"
}

variable "efs_properties" {
  description = "A map of EFS properties"
  type        = map(string)
  default = {
    creation_token = "clixx-EFS"
    encrypted      = true
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidr" {
  type    = list(string)
  default = ["10.0.2.0/23", "10.0.4.0/23"]
}

variable "app_subnet_cidr" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "multi_az_rds_subnet_cidr" {
  type    = list(string)
  default = ["10.0.20.0/22", "10.0.24.0/22"]
}

variable "oracle_db_subnet_cidr" {
  type    = list(string)
  default = ["10.0.30.0/24", "10.0.31.0/24"]
}
variable "java_app_subnet_cidr" {
  type    = list(string)
  default = ["10.0.40.0/26", "10.0.41.0/26"]
}

variable "java_app_db_subnet_cidr" {
  type    = list(string)
  default = ["10.0.42.0/26", "10.0.43.0/26"]
}

variable "container_name" {
  description = "The name of the container in the ECS task definition"
  type        = string
  default     = "clixx-cont"
}
