resource "aws_ecr_repository" "release" {
  name                 = "tire-testing-release"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "tire-testing-release" }
}

resource "aws_ecr_repository" "snapshot" {
  name                 = "tire-testing-snapshot"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "tire-testing-snapshot" }
}

resource "aws_ecr_lifecycle_policy" "release" {
  repository = aws_ecr_repository.release.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "snapshot" {
  repository = aws_ecr_repository.snapshot.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}


//GitOps
resource "aws_ecr_repository" "gitops_release" {
  name                 = "tire-testing-gitops-release"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "tire-testing-gitops-release" }
}

resource "aws_ecr_repository" "gitops_snapshot" {
  name                 = "tire-testing-gitops-snapshot"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "tire-testing-gitops-snapshot" }
}

resource "aws_ecr_lifecycle_policy" "gitops_release" {
  repository = aws_ecr_repository.gitops_release.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "gitops_snapshot" {
  repository = aws_ecr_repository.gitops_snapshot.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}


output "ecr_release_arn" { value = aws_ecr_repository.release.arn }
output "ecr_snapshot_arn" { value = aws_ecr_repository.snapshot.arn }
output "ecr_release_url" { value = aws_ecr_repository.release.repository_url }
output "ecr_snapshot_url" { value = aws_ecr_repository.snapshot.repository_url }

//GitOps
output "ecr_gitops_release_arn"  { value = aws_ecr_repository.gitops_release.arn }
output "ecr_gitops_snapshot_arn" { value = aws_ecr_repository.gitops_snapshot.arn }
output "ecr_gitops_release_url"  { value = aws_ecr_repository.gitops_release.repository_url }
output "ecr_gitops_snapshot_url" { value = aws_ecr_repository.gitops_snapshot.repository_url }