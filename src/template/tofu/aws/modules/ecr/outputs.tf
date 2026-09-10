data "aws_caller_identity" "this" {}

output "registry" {
  value = "${data.aws_caller_identity.this.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "repository_urls" {
  value = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_arns" {
  value = [for repo in values(aws_ecr_repository.this) : repo.arn]
}
