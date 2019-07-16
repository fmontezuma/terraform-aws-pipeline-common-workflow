version: 0.2
phases:
  install:
    runtime-versions:
      docker: 18
    commands:
      - echo Logging in to Amazon ECR...
      - $(aws ecr get-login --no-include-email --region ${region})
      - git config --global credential.helper '!aws codecommit credential-helper $@'
      - git config --global credential.UseHttpPath true
      - git config --global user.email ""
      - git config --global user.name "AWS Pipeline"
      #- curl -fsSL https://raw.githubusercontent.com/thii/aws-codebuild-extras/master/install >> extras.sh && . ./extras.sh
      - git clone https://git-codecommit.${region}.amazonaws.com/v1/repos/devops
      - ENV="${env_val}"
      - TAG="$${ENV}-$${TAG:-$CODEBUILD_RESOLVED_SOURCE_VERSION}"
      - MANIFEST=$(aws ecr batch-get-image --repository-name ${project_name} --image-ids imageTag=$CODEBUILD_RESOLVED_SOURCE_VERSION --query 'images[].imageManifest' --output text)
      - aws ecr put-image --repository-name ${project_name} --image-tag $TAG --image-manifest "$MANIFEST" || true
      - git clone --branch $ENV https://git-codecommit.${region}.amazonaws.com/v1/repos/k8s-deployment
      - cd devops/helm
      - git clone https://github.com/fmontezuma/helm-microservice.git
  build:
    commands:
      - docker run --rm -v $(pwd):/apps -v ~/.kube/config:/root/.kube/config alpine/helm:2.9.0 template ./helm-microservice -f values/${project_name}/common.yml -f values/${project_name}/$ENV.yml --set image.tag=$TAG > ${project_name}.yml
      - mv ${project_name}.yml ../../k8s-deployment/microservices/${project_name}.yml
      - cd ../../k8s-deployment
      - git add --all
      - git commit -m "${project_name} - $${TAG}"
      - git push origin $ENV
