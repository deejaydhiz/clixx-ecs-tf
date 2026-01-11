
resource "aws_key_pair" "this" {
  key_name   = "clixx-kp"
  public_key = file(var.public_key_path)
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_attachment" {
  role       = var.ec2_properties["iam_instance_profile"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# The "Execution Role" allows ECS to pull the image and fetch SSM secrets
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "clixx-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# Attach the standard Amazon policy for ECR and CloudWatch logs
resource "aws_iam_role_policy_attachment" "execution_role_standard" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Add a specific policy to allow reading the SSM Parameter
resource "aws_iam_role_policy" "ssm_read" {
  name = "allow-ssm-read"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameters", "kms:Decrypt"]
      Resource = ["${data.aws_ssm_parameter.db_pass.arn}"]
    }]
  })
}

resource "aws_db_instance" "clixx_rds_instance" {
  identifier              = "wordpressdbclixxjenkins"
  instance_class          = "db.t4g.micro"
  engine                  = "mysql"
  snapshot_identifier     = "wordpressdbclixxsnap"
  skip_final_snapshot     = true
  publicly_accessible     = false
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]

  tags = {
    Name = "clixx-rds-instance"
  }
}

### Create a Route53 record for Load Balancer DNS ###
resource "aws_route53_record" "this" {
  provider = aws.management
  zone_id  = data.aws_route53_zone.mydns.zone_id
  name     = "ecs.${data.aws_route53_zone.mydns.name}"
  type     = "A"
  
  set_identifier = "ecs.deji-stack.com"

  alias {
    name                   = aws_lb.clixx_alb.dns_name
    zone_id                = aws_lb.clixx_alb.zone_id
    evaluate_target_health = true
  } 
}

resource "aws_ecs_cluster" "clixx_ecs_cluster" {
  name = "clixx-ecs-cluster"

}

resource "aws_ecs_task_definition" "clixx_db_init" {
  family                   = "clixx-db-init"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "db-init"
      image     = "${data.aws_ecr_repository.clixx_repo.repository_url}@${data.aws_ecr_image.clixx_image.image_digest}"
      essential = true

      command = [
        "sh",
        "-c",
        <<-EOT
          set -e

          echo "Waiting for database..."
          until mysql -h "$WORDPRESS_DB_HOST" \
            -u "$WORDPRESS_DB_USER" \
            -p"$WORDPRESS_DB_PASSWORD" \
            -e "select 1"; do
            sleep 5
          done

          echo "Running DB initialization..."
          mysql -h "$WORDPRESS_DB_HOST" \
            -u "$WORDPRESS_DB_USER" \
            -p"$WORDPRESS_DB_PASSWORD" \
            "$WORDPRESS_DB_NAME" <<'SQL'
          UPDATE wp_options
          SET option_value='http://ecs.deji-stack.com'
          WHERE option_name IN ('home','siteurl');
          SQL

          echo "DB init completed"
        EOT
      ]

      environment = [
        { name = "WORDPRESS_DB_HOST", value = aws_db_instance.clixx_rds_instance.address },
        { name = "WORDPRESS_DB_USER", value = "wordpressuser" },
        { name = "WORDPRESS_DB_NAME", value = "wordpressdb" }
      ]

      secrets = [
        {
          name      = "WORDPRESS_DB_PASSWORD"
          valueFrom = data.aws_ssm_parameter.db_pass.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.clixx_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "db-init"
        }
      }
    }
  ])
}

resource "aws_cloudwatch_log_group" "clixx_log_group" {
  name = "/ecs/clixx-task"
  retention_in_days = 7
}

resource "aws_lb" "clixx_alb" {
  name               = "clixx-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_sg.id]
  subnets            = [for subnet in aws_subnet.public_subnet : subnet.id]

  tags = {
    Environment = "dev"
  }
}

resource "aws_lb_target_group" "clixx_tg" {
  name     = "clixx-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.deployment_vpc.id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    path                = "/index.php"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_listener" "clixx_listener" {
  load_balancer_arn = aws_lb.clixx_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clixx_tg.arn
  }
}

resource "aws_launch_template" "clixx_lt" {
  name_prefix   = "clixx-lt-"
  image_id      = data.aws_ami.ecs_ami.id
  instance_type = var.ec2_properties["instance_type"]
  key_name      = aws_key_pair.this.key_name

  vpc_security_group_ids = [
    aws_security_group.app_sg.id
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    echo "ECS_CLUSTER=${aws_ecs_cluster.clixx_ecs_cluster.name}" >> /etc/ecs/ecs.config
    echo "ECS_ENABLE_CONTAINER_METADATA=true" >> /etc/ecs/ecs.config
  EOF
  )

  iam_instance_profile {
    name = var.ec2_properties["iam_instance_profile"]
  }
}

resource "aws_autoscaling_group" "clixx_asg" {
  name = "clixx-asg"

  min_size = 1
  max_size = 3
  desired_capacity = 2
  force_delete = true

  launch_template {
    id      = aws_launch_template.clixx_lt.id
    version = "$Latest"
  }

  vpc_zone_identifier = [ for subnet in aws_subnet.app_subnet : subnet.id ]

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

resource "aws_ecs_service" "clixx_service" {
  name                 = "clixx-service"
  cluster              = aws_ecs_cluster.clixx_ecs_cluster.id
  task_definition      = aws_ecs_task_definition.clixx_task.arn
  desired_count        = 2
  force_new_deployment = true
  force_delete         = true
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets         = [for subnet in aws_subnet.app_subnet : subnet.id]
    security_groups = [aws_security_group.app_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.clixx_tg.arn
    container_name   = var.container_name
    container_port   = 80
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    weight            = 100
  }
}

resource "aws_ecs_capacity_provider" "ec2" {
  name = "packer-ami-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.clixx_asg.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 80
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.clixx_ecs_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.ec2.name]
}

resource "null_resource" "run_db_init" {
  depends_on = [
    aws_ecs_cluster.clixx_ecs_cluster,
    aws_db_instance.clixx_rds_instance
  ]

  provisioner "local-exec" {
    command = <<EOT
      aws ecs run-task \
        --cluster ${aws_ecs_cluster.clixx_ecs_cluster.name} \
        --task-definition ${aws_ecs_task_definition.clixx_db_init.family} \
        --launch-type EC2 \
        --network-configuration "awsvpcConfiguration={subnets=[${aws_subnet.app_subnet[0].id}],securityGroups=[${aws_security_group.app_sg.id}]}"
    EOT
  }
}
