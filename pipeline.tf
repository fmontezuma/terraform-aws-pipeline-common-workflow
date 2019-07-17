resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "${format("%.63s", "${data.aws_caller_identity.current.account_id}-${var.project_name}-pipeline")}"
  acl    = "private"
}

resource "aws_codepipeline" "codepipeline" {
  name     = "${var.project_name}"
  role_arn = "${var.codepipeline_role_arn}"

  artifact_store {
    location = "${aws_s3_bucket.codepipeline_bucket.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = "${var.project_name}"
        BranchName = "master"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"

      configuration = {
        ProjectName = "${aws_codebuild_project.build.name}"
      }
    }
  }

  stage {
    name = "Develop"

    action {
      name             = "DevelopDeploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"

      configuration = {
        ProjectName = "${aws_codebuild_project.deploy[0].name}"
      }
    }
  }

  stage {
    name = "DevelopApproval"

    action {
      name     = "DevelopApproval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      configuration = {
        ExternalEntityLink = "http://${var.project_name}-${var.environments[0]}.${var.dnsSuffixDev}"
      }
    }
  }

  stage {
    name = "Homolog"

    action {
      name             = "HomologDeploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"

      configuration = {
        ProjectName = "${aws_codebuild_project.deploy[1].name}"
      }
    }

    action {
      name     = "HomologApproval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      configuration = {
        ExternalEntityLink = "http://${var.project_name}-${var.environments[1]}.${var.dnsSuffixHml}"
      }
    }
  }

  stage {
    name = "Production"

    action {
      name             = "ProductionDeploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"

      configuration = {
        ProjectName = "${aws_codebuild_project.deploy[2].name}"
      }
    }
  }

}
