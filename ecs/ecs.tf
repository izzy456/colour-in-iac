# Logging
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = var.project_name
  retention_in_days = 7

  # lifecycle {
  #   prevent_destroy = true
  # }
}

# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.project_name

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_logs.name
      }
    }
  }

  # lifecycle {
  #   prevent_destroy = true
  # }
}

# ECS Task execution role
data "aws_iam_role" "ecs_execution_role" {
  name = "ecsTaskExecutionRole"
}