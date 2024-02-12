# SG for backend ALB (allow traffic from frontend service)
resource "aws_security_group" "alb_sg_backend" {
  name        = "${var.project_name}-backend-alb-sg"
  description = "ALB SG backend"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Allow frontend ECS Service on port 8080"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.service_sg_frontend.id]
  }
  ingress {
    description     = "Allow frontend ECS Service on port 8081"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.service_sg_frontend.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG for backend service
resource "aws_security_group" "service_sg_backend" {
  name        = "${var.project_name}-backend-ecs-sg"
  description = "ECS SG backend"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Allow backend ALB on port 8080"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg_backend.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Prod Task
resource "aws_ecs_task_definition" "ecs_task_def_backend_prod" {
  family                   = "${var.project_name}-backend-prod"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.aws_iam_role.ecs_execution_role.arn
  network_mode             = "awsvpc"

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-backend-prod"
      image     = "public.ecr.aws/nginx/nginx:stable-perl"
      cpu       = 256
      memory    = 512
      essential = true
      command   = ["-p", "8080:80"]
      portMappings = [
        {
          containerPort = 8080
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "true",
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = "ecs-backend-prod"
        }
      }
    }
  ])

  lifecycle {
    ignore_changes = all
  }
}

# Test Task
resource "aws_ecs_task_definition" "ecs_task_def_backend_test" {
  family                   = "${var.project_name}-backend-test"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.aws_iam_role.ecs_execution_role.arn
  network_mode             = "awsvpc"

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-backend-test"
      image     = "public.ecr.aws/nginx/nginx:stable-perl"
      cpu       = 256
      memory    = 512
      essential = true
      command   = ["-p", "8080:80"]
      portMappings = [
        {
          containerPort = 8080
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "true",
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = "ecs-backend-test"
        }
      }
    }
  ])

  lifecycle {
    ignore_changes = all
  }
}

# Prod Service
resource "aws_ecs_service" "ecs_service_backend_prod" {
  name            = "${var.project_name}-backend-prod"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  desired_count   = 0
  task_definition = aws_ecs_task_definition.ecs_task_def_backend_prod.arn
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = false
    subnets          = aws_subnet.private_subnet.*.id
    security_groups  = [aws_security_group.service_sg_backend.id]
  }

  deployment_controller {
    type = "ECS"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.lb_target_group_backend_prod.arn
    container_name   = "${var.project_name}-backend-prod"
    container_port   = 8080
  }

  lifecycle {
    ignore_changes = all
  }
}

# Test Service
resource "aws_ecs_service" "ecs_service_backend_test" {
  name            = "${var.project_name}-backend-test"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  desired_count   = 0
  task_definition = aws_ecs_task_definition.ecs_task_def_backend_prod.arn
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = false
    subnets          = aws_subnet.private_subnet.*.id
    security_groups  = [aws_security_group.service_sg_backend.id]
  }

  deployment_controller {
    type = "ECS"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.lb_target_group_backend_test.arn
    container_name   = "${var.project_name}-backend-test"
    container_port   = 8080
  }

  lifecycle {
    ignore_changes = all
  }

  tags = {
    environment = "test"
  }
}

# LB
resource "aws_lb" "lb_backend" {
  name               = "${var.project_name}-backend-lb"
  load_balancer_type = "application"
  subnets            = aws_subnet.private_subnet.*.id
  security_groups    = [aws_security_group.alb_sg_backend.id]
  internal           = true
}

# Prod TG
resource "aws_lb_target_group" "lb_target_group_backend_prod" {
  name        = "${var.project_name}-backend-prod"
  target_type = "ip"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 30
    matcher             = 200
    path                = "/docs"
    port                = 8080
    protocol            = "HTTP"
    timeout             = 6
    unhealthy_threshold = 3
  }
}

# TG Test
resource "aws_lb_target_group" "lb_target_group_backend_test" {
  name        = "${var.project_name}-backend-test"
  target_type = "ip"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 30
    matcher             = 200
    path                = "/docs"
    port                = 8080
    protocol            = "HTTP"
    timeout             = 6
    unhealthy_threshold = 3
  }

  tags = {
    environment = "test"
  }
}

resource "aws_lb_listener" "lb_listener_backend_prod" {
  port              = 8080
  protocol          = "HTTP"
  load_balancer_arn = aws_lb.lb_backend.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group_backend_prod.arn
  }
}

resource "aws_lb_listener" "lb_listener_backend_test" {
  port              = 8081
  protocol          = "HTTP"
  load_balancer_arn = aws_lb.lb_backend.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group_backend_test.arn
  }

  tags = {
    environment = "test"
  }
}