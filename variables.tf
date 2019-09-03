variable codepipeline_role_arn {}
variable codebuild_deploy_role_arn {}
variable codebuild_role_arn {}
variable project_name {}
variable microservice_name {}
variable dnsSuffixDev {}
variable dnsSuffixHml {}
variable pipeline_s3_bucket {}

variable "only_deploy" {
  description = "If true, this pipeline will only deploy, not build"
  type        = bool
  default     = false
}
