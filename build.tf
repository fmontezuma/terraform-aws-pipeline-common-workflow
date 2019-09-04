data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_codebuild_project" "build" {
  count = var.only_deploy ? 0 : 1

  name          = "${var.project_name}-${var.microservice_name}-build"
  description   = "Build process for ${var.project_name}-${var.microservice_name}"
  service_role  = "${var.codebuild_role_arn}"

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:2.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode = "true"
  }

  dynamic "vpc_config" {
    for_each = var.build_vpc_id == "" ? [0] : [1]
    content {
      vpc_id = var.build_vpc_id
      subnets = var.build_subnet_ids 
      security_group_ids = var.build_security_group_ids
    }
  }

  source {
    type            = "CODECOMMIT"
    location        = "https://git-codecommit.${data.aws_region.current.name}.amazonaws.com/v1/repos/${var.project_name}-${var.microservice_name}"
    git_clone_depth = 1
    buildspec = templatefile("${path.module}/build-buildspec.json.tpl", { project_name = "${var.project_name}", microservice_name = "${var.microservice_name}", account_id = "${data.aws_caller_identity.current.account_id}", region = "${data.aws_region.current.name}" })
  }
}
