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