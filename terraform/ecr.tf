resource "aws_ecr_repository" "app" {
  name = "final-dm-dos35"
  image_tag_mutability = "MUTABLE"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

#ecr_repository_url = "224843962620.dkr.ecr.us-west-1.amazonaws.com/final-dm-dos35"#