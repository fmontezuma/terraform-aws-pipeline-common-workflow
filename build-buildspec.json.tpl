version: 0.2
phases:
  install:
    runtime-versions:
      docker: 18
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - $(aws ecr get-login --no-include-email --region ${region})
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t ${account_id}.dkr.ecr.${region}.amazonaws.com/${project_name}:$CODEBUILD_RESOLVED_SOURCE_VERSION .
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker image...
      - docker push ${account_id}.dkr.ecr.${region}.amazonaws.com/${project_name}:$CODEBUILD_RESOLVED_SOURCE_VERSION
