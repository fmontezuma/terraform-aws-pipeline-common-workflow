resource "aws_ecr_repository" "ecr" {
  name = "${var.project_name}"
}
