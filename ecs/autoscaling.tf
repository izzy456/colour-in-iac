# Frontend Prod
resource "aws_appautoscaling_target" "autoscaling_frontend_prod" {
  max_capacity       = 5
  min_capacity       = 0
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.ecs_service_frontend_prod.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Memory
resource "aws_appautoscaling_policy" "frontend_memory_policy_prod" {
  name               = "frontend-memory-policy-prod"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.autoscaling_frontend_prod.resource_id
  scalable_dimension = aws_appautoscaling_target.autoscaling_frontend_prod.scalable_dimension
  service_namespace  = aws_appautoscaling_target.autoscaling_frontend_prod.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80
  }
}

# CPU
resource "aws_appautoscaling_policy" "frontend_cpu_policy_prod" {
  name               = "frontend-cpu-policy-prod"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.autoscaling_frontend_prod.resource_id
  scalable_dimension = aws_appautoscaling_target.autoscaling_frontend_prod.scalable_dimension
  service_namespace  = aws_appautoscaling_target.autoscaling_frontend_prod.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 60
  }
}

# Backend Prod
resource "aws_appautoscaling_target" "autoscaling_backend_prod" {
  max_capacity       = 5
  min_capacity       = 0
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.ecs_service_backend_prod.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Memory
resource "aws_appautoscaling_policy" "backend_memory_policy_prod" {
  name               = "backend-memory-policy-prod"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.autoscaling_backend_prod.resource_id
  scalable_dimension = aws_appautoscaling_target.autoscaling_backend_prod.scalable_dimension
  service_namespace  = aws_appautoscaling_target.autoscaling_backend_prod.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80
  }
}

resource "aws_appautoscaling_policy" "backend_cpu_policy_prod" {
  name               = "backend-cpu-policy-prod"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.autoscaling_backend_prod.resource_id
  scalable_dimension = aws_appautoscaling_target.autoscaling_backend_prod.scalable_dimension
  service_namespace  = aws_appautoscaling_target.autoscaling_backend_prod.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 60
  }
}