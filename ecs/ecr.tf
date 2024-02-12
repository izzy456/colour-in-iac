# Frontend ECR Repo
resource "aws_ecr_repository" "ecr_repo_frontend" {
  name                 = "${var.project_name}-frontend"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

# Backend ECR Repo
resource "aws_ecr_repository" "ecr_repo_backend" {
  name                 = "${var.project_name}-backend"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

# Frontend ECR Repo - Test
resource "aws_ecr_repository" "ecr_repo_frontend_test" {
  name                 = "${var.project_name}-frontend-test"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

# Backend ECR Repo - Test
resource "aws_ecr_repository" "ecr_repo_backend_test" {
  name                 = "${var.project_name}-backend-test"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}