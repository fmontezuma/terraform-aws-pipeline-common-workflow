resource "aws_ecr_repository" "ecr" {
  name = "${var.project_name}-${var.microservice_name}"
}

resource "aws_ecr_repository_policy" "cross_account" {
  repository = "${aws_ecr_repository.ecr.name}"

  policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "cross-account-access",
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:DescribeImages",
                "ecr:BatchGetImage"
            ]
        }
    ]
}
EOF
}
