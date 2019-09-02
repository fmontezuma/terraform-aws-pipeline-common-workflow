variable "environments" {
    type    = "list"
    default = ["dev", "hml", "prd"]
}

resource "aws_codebuild_project" "deploy" {
  count = length(var.environments)

  name          = "${var.project_name}-${var.microservice_name}-deploy-${var.environments[count.index]}"
  description   = "Deploy process for ${var.project_name}-${var.microservice_name}"
  service_role  = "${var.codebuild_deploy_role_arn}"

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

  source {
    type            = "CODECOMMIT"
    location        = "https://git-codecommit.${data.aws_region.current.name}.amazonaws.com/v1/repos/${var.project_name}-${var.microservice_name}"
    git_clone_depth = 1
    buildspec = templatefile("${path.module}/deploy-buildspec.json.tpl", { project_name = "${var.project_name}", microservice_name = "${var.microservice_name}", env_val = "${var.environments[count.index]}", region = "${data.aws_region.current.name}" })
  }
}
