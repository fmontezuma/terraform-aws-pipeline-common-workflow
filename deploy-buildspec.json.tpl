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
      - git clone https://git-codecommit.${region}.amazonaws.com/v1/repos/${project_name}-devops
      - ENV="${env_val}"
      - TAG="$${ENV}-$${TAG:-$CODEBUILD_RESOLVED_SOURCE_VERSION}"
      - MANIFEST=$(aws ecr batch-get-image --repository-name ${project_name}-${microservice_name} --image-ids imageTag=$CODEBUILD_RESOLVED_SOURCE_VERSION --query 'images[].imageManifest' --output text)
      - aws ecr put-image --repository-name ${project_name}-${microservice_name} --image-tag $TAG --image-manifest "$MANIFEST" || true
      - git clone --branch $ENV https://git-codecommit.${region}.amazonaws.com/v1/repos/${project_name}-k8s-deploy
      - cd ${project_name}-devops/helm
      - helm repo add fmontezuma-$ENV https://fmontezuma.github.io/helm-chart/$ENV
      - helm fetch fmontezuma/microservice --untar
  build:
    commands:
      - docker run --rm -v $(pwd):/apps -v ~/.kube/config:/root/.kube/config alpine/helm:2.9.0 template ./microservice -f values/${project_name}-${microservice_name}/common.yml -f values/${project_name}-${microservice_name}/$ENV.yml --set image.tag=$TAG > ${project_name}-${microservice_name}.yml
      - mv ${project_name}-${microservice_name}.yml ../../k8s-deploy/microservices/${project_name}-${microservice_name}.yml
      - cd ../../${project_name}-k8s-deploy
      - git add --all
      - git commit -m "${project_name}-${microservice_name} - $${TAG}"
      - git push origin $ENV
