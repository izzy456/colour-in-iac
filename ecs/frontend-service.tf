# SG for frontend ALB (public)
resource "aws_security_group" "alb_sg_frontend" {
  depends_on  = [aws_vpc.vpc]
  name        = "${var.project_name}-frontend-alb-sg"
  description = "ALB SG frontend"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow all HTTP to ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow all HTTPS to ALB"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb_sg_frontend_no_cert" {
  depends_on  = [aws_vpc.vpc]
  name        = "${var.project_name}-frontend-alb-sg-test"
  description = "ALB SG frontend test"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow all HTTP to ALB on ${var.app_port}"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG for frontend service
resource "aws_security_group" "service_sg_frontend" {
  depends_on  = [aws_security_group.alb_sg_frontend]
  name        = "${var.project_name}-frontend-ecs-sg"
  description = "ECS SG frontend"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Only allow ALB to ECS"
    from_port       = 0
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = var.cert_domain == "" ? [aws_security_group.alb_sg_frontend_no_cert.id] : [aws_security_group.alb_sg_frontend.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Task
resource "aws_ecs_task_definition" "ecs_task_def_frontend" {
  family                   = "${var.project_name}-frontend"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.aws_iam_role.ecs_execution_role.arn
  network_mode             = "awsvpc"

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-frontend"
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
resource "aws_ecs_service" "ecs_service_frontend" {
  depends_on      = [aws_ecs_cluster.ecs_cluster, aws_subnet.private_subnet, aws_lb_target_group.lb_target_group_frontend]
  name            = "${var.project_name}-frontend"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  desired_count   = 0
  task_definition = aws_ecs_task_definition.ecs_task_def_frontend.arn
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = false
    subnets          = aws_subnet.private_subnet.*.id
    security_groups  = [aws_security_group.service_sg_frontend.id]
  }

  deployment_controller {
    type = "ECS"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.lb_target_group_frontend.arn
    container_name   = "${var.project_name}-frontend"
    container_port   = var.app_port
  }

  lifecycle {
    ignore_changes = all
  }
}

# Test Service
resource "aws_ecs_service" "ecs_service_frontend_test" {
  depends_on      = [aws_ecs_cluster.ecs_cluster, aws_subnet.private_subnet, aws_lb_target_group.lb_target_group_frontend]
  name            = "${var.project_name}-frontend-test"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  desired_count   = 0
  task_definition = aws_ecs_task_definition.ecs_task_def_frontend.arn
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = false
    subnets          = aws_subnet.private_subnet.*.id
    security_groups  = [aws_security_group.service_sg_frontend.id]
  }

  deployment_controller {
    type = "ECS"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.lb_target_group_frontend_test.arn
    container_name   = "${var.project_name}-frontend"
    container_port   = var.app_port
  }

  lifecycle {
    ignore_changes = all
  }
}

# LB
resource "aws_lb" "lb_frontend" {
  depends_on         = [aws_subnet.public_subnet]
  name               = "${var.project_name}-frontend-lb"
  load_balancer_type = "application"
  subnets            = aws_subnet.public_subnet.*.id
  security_groups    = "${var.cert_domain}" == "" ? [aws_security_group.alb_sg_frontend_no_cert.id] : [aws_security_group.alb_sg_frontend.id]
}

# TG
resource "aws_lb_target_group" "lb_target_group_frontend" {
  depends_on  = [aws_vpc.vpc]
  name        = "${var.project_name}-frontend"
  target_type = "ip"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 30
    matcher             = 200
    path                = "/"
    port                = var.app_port
    protocol            = "HTTP"
    timeout             = 6
    unhealthy_threshold = 3
  }
}

# TG Test
resource "aws_lb_target_group" "lb_target_group_frontend_test" {
  depends_on  = [aws_vpc.vpc]
  name        = "${var.project_name}-frontend-test"
  target_type = "ip"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 30
    matcher             = 200
    path                = "/"
    port                = var.app_port
    protocol            = "HTTP"
    timeout             = 6
    unhealthy_threshold = 3
  }
}

data "aws_acm_certificate" "app_certificate" {
  count  = "${var.cert_domain}" == "" ? 0 : 1
  domain = var.cert_domain
}

data "aws_route53_zone" "project_hosted_zone" {
  count = "${var.cert_domain}" == "" ? 0 : 1
  name  = var.hosted_zone
}

resource "aws_route53_record" "app_record" {
  zone_id = data.aws_route53_zone.project_hosted_zone[0].zone_id
  name    = var.hosted_zone
  type    = "A"
  ttl     = 300
  records = [aws_lb.lb_frontend.dns_name]
}

resource "aws_lb_listener" "lb_listener_frontend_secure" {
  count             = "${var.cert_domain}" == "" ? 0 : 1
  depends_on        = [aws_lb_target_group.lb_target_group_frontend]
  port              = 443
  protocol          = "HTTPS"
  load_balancer_arn = aws_lb.lb_frontend.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group_frontend.arn
  }

  certificate_arn = data.aws_acm_certificate.app_certificate[0].arn
  ssl_policy      = "ELBSecurityPolicy-2016-08"
}

resource "aws_lb_listener_rule" "listener_rule_experimental" {
  count        = "${var.cert_domain}" == "" ? 0 : 1
  listener_arn = aws_lb_listener.lb_listener_frontend_secure[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group_frontend_test.arn
  }

  condition {
    path_pattern {
      values = ["/experimental/*"]
    }
  }
}

resource "aws_lb_listener" "lb_listener_frontend" {
  count             = "${var.cert_domain}" == "" ? 0 : 1
  depends_on        = [aws_lb.lb_frontend]
  port              = 80
  protocol          = "HTTP"
  load_balancer_arn = aws_lb.lb_frontend.arn

  default_action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      port        = 443
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "lb_listener_frontend_no_cert" {
  count             = "${var.cert_domain}" == "" ? 1 : 0
  depends_on        = [aws_lb.lb_frontend]
  port              = 80
  protocol          = "HTTP"
  load_balancer_arn = aws_lb.lb_frontend.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group_frontend.arn
  }
}

resource "aws_lb_listener_rule" "listener_rule_experimental_no_cert" {
  count        = "${var.cert_domain}" == "" ? 1 : 0
  listener_arn = aws_lb_listener.lb_listener_frontend_no_cert[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group_frontend_test.arn
  }

  condition {
    path_pattern {
      values = ["/experimental/*"]
    }
  }
}