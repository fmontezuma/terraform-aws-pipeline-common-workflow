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
      - ${only_deploy} || MANIFEST=$(aws ecr batch-get-image --repository-name ${project_name}-${microservice_name} --image-ids imageTag=$CODEBUILD_RESOLVED_SOURCE_VERSION --query 'images[].imageManifest' --output text)
      - TAG="${env_val}-$${TAG:-$CODEBUILD_RESOLVED_SOURCE_VERSION}"
      - ${only_deploy} || (aws ecr put-image --repository-name ${project_name}-${microservice_name} --image-tag $TAG --image-manifest "$MANIFEST" || true)
      - TAG2="${env_val}"
      - ${only_deploy} || (aws ecr put-image --repository-name ${project_name}-${microservice_name} --image-tag $TAG2 --image-manifest "$MANIFEST" || true)
      - CMD0="helm init --client-only"
      - CMD1="helm repo add fmontezuma-${env_val} https://fmontezuma.github.io/helm-chart/${env_val}"
      - CMD2="helm fetch fmontezuma-${env_val}/microservice --untar"
      - CMD3="helm template ./microservice -f ${project_name}-devops/helm/values/globals/${env_val}.yml -f ${project_name}-devops/helm/values/${project_name}-${microservice_name}/common.yml -f ${project_name}-devops/helm/values/${project_name}-${microservice_name}/${env_val}.yml --set image.tag=$${TAG} > ${project_name}-${microservice_name}.yml"
      - HELM_CMD="$CMD0;$CMD1;$CMD2;$CMD3"
  build:
    commands:
      - docker run --rm --entrypoint "/bin/sh" -v $(pwd):/apps -v ~/.kube/config:/root/.kube/config alpine/helm:2.9.0 -c "$HELM_CMD"
      - git clone https://git-codecommit.${region}.amazonaws.com/v1/repos/${project_name}-k8s-deploy
      - cd ${project_name}-k8s-deploy
      - git checkout ${env_val} 2>/dev/null || git checkout -b ${env_val}
      - cd ..
      - mkdir -p ${project_name}-k8s-deploy/microservices
      - mv ${project_name}-${microservice_name}.yml ${project_name}-k8s-deploy/microservices/${project_name}-${microservice_name}.yml
      - cd ${project_name}-k8s-deploy
      - git add --all
      - git commit --allow-empty -m "${project_name}-${microservice_name} - $${TAG}"
      - git push origin ${env_val}
      - CREDENTIALS=$(aws sts assume-role --role-arn arn:aws:iam::${account_id}:role/kubectl --role-session-name codebuild-kubectl --duration-seconds 900)
      - export AWS_ACCESS_KEY_ID="$(echo $${CREDENTIALS} | jq -r '.Credentials.AccessKeyId')"
      - export AWS_SECRET_ACCESS_KEY="$(echo $${CREDENTIALS} | jq -r '.Credentials.SecretAccessKey')"
      - export AWS_SESSION_TOKEN="$(echo $${CREDENTIALS} | jq -r '.Credentials.SessionToken')"
      - export AWS_EXPIRATION=$(echo $${CREDENTIALS} | jq -r '.Credentials.Expiration')
      - cd ../${project_name}-devops/helm/values/${project_name}-${microservice_name}
      - aws eks update-kubeconfig --name ${project_name}-${env_val} --kubeconfig kubeconfig.yml
      - APP_NAME=$(grep -Po 'appName:[ ]\K.*' common.yml)
      - echo $APP_NAME
      - NAMESPACE=$(grep -Po 'namespace:[ ]\K.*' common.yml)
      - echo $NAMESPACE
      - LAST_VERSION=$(kubectl -n=$NAMESPACE get deployment $APP_NAME -o jsonpath={.status.observedGeneration} --kubeconfig kubeconfig.yml)
      - echo $LAST_VERSION
      - LAST_VERSION=$${LAST_VERSION:-""}
      - |
        currentVersion=$(kubectl -n=$NAMESPACE get deployment/$APP_NAME -o jsonpath={.status.observedGeneration} --kubeconfig kubeconfig.yml)
        while [ $LAST_VERSION -eq $currentVersion ]
        do 
          echo "Waiting deploy start.."
          sleep 10
          currentVersion=$(kubectl -n=$NAMESPACE get deployment/$APP_NAME -o jsonpath={.status.observedGeneration} --kubeconfig kubeconfig.yml)
        done
      - kubectl -n=$NAMESPACE rollout status deployment/$APP_NAME --kubeconfig kubeconfig.yml
