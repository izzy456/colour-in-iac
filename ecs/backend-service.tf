# SG for backend ALB (allow traffic from frontend service)
resource "aws_security_group" "alb_sg_backend" {
  depends_on  = [aws_vpc.vpc]
  name        = "${var.project_name}-backend-alb-sg"
  description = "ALB SG backend"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Allow frontend ECS Service from port 8080"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.service_sg_frontend.id]
  }
  ingress {
    description     = "Allow frontend ECS Service from port 8081"
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
  depends_on  = [aws_security_group.alb_sg_backend]
  name        = "${var.project_name}-backend-ecs-sg"
  description = "ECS SG backend"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Allow backend ALB"
    from_port       = var.app_port
    to_port         = var.app_port
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

# Task
resource "aws_ecs_task_definition" "ecs_task_def_backend" {
  family                   = "${var.project_name}-backend"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.aws_iam_role.ecs_execution_role.arn
  network_mode             = "awsvpc"

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-backend"
      image     = "public.ecr.aws/nginx/nginx:stable-perl"
      cpu       = 256
      memory    = 512
      essential = true
      command   = ["-p", "${var.app_port}:80"]
      portMappings = [
        {
          containerPort = var.app_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "true",
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = "${var.project_name}-task"
        }
      }
    }
  ])

  lifecycle {
    ignore_changes = all
  }
}

# Service
resource "aws_ecs_service" "ecs_service_backend" {
  depends_on      = [aws_ecs_cluster.ecs_cluster, aws_subnet.private_subnet, aws_lb_target_group.lb_target_group_backend]
  name            = "${var.project_name}-backend"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  desired_count   = 0
  task_definition = aws_ecs_task_definition.ecs_task_def_backend.arn
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
    target_group_arn = aws_lb_target_group.lb_target_group_backend.arn
    container_name   = "${var.project_name}-backend"
    container_port   = var.app_port
  }

  lifecycle {
    ignore_changes = all
  }
}

# Service Test
resource "aws_ecs_service" "ecs_service_backend_test" {
  depends_on      = [aws_ecs_cluster.ecs_cluster, aws_subnet.private_subnet, aws_lb_target_group.lb_target_group_backend]
  name            = "${var.project_name}-backend-test"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  desired_count   = 0
  task_definition = aws_ecs_task_definition.ecs_task_def_backend.arn
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
    container_name   = "${var.project_name}-backend"
    container_port   = var.app_port
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
  depends_on         = [aws_subnet.private_subnet]
  name               = "${var.project_name}-backend-lb"
  load_balancer_type = "application"
  subnets            = aws_subnet.private_subnet.*.id
  security_groups    = [aws_security_group.alb_sg_backend.id]
  internal           = true
}

# TG
resource "aws_lb_target_group" "lb_target_group_backend" {
  depends_on  = [aws_vpc.vpc]
  name        = "${var.project_name}-backend"
  target_type = "ip"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 30
    matcher             = 200
    path                = "/docs"
    port                = var.app_port
    protocol            = "HTTP"
    timeout             = 6
    unhealthy_threshold = 3
  }
}

# TG Test
resource "aws_lb_target_group" "lb_target_group_backend_test" {
  depends_on  = [aws_vpc.vpc]
  name        = "${var.project_name}-backend-test"
  target_type = "ip"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 30
    matcher             = 200
    path                = "/docs"
    port                = var.app_port
    protocol            = "HTTP"
    timeout             = 6
    unhealthy_threshold = 3
  }

  tags = {
    environment = "test"
  }
}

resource "aws_lb_listener" "lb_listener_backend" {
  depends_on        = [aws_lb_target_group.lb_target_group_backend]
  port              = var.app_port
  protocol          = "HTTP"
  load_balancer_arn = aws_lb.lb_backend.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group_backend.arn
  }
}

resource "aws_lb_listener" "lb_listener_backend_test" {
  depends_on        = [aws_lb_target_group.lb_target_group_backend_test]
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