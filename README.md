# TMAS Container

## Description

`tmas` is a CLI tool that performs open source vulnerability scanning and report generation for artifacts. It first takes the artifact that you wish to be scanned and generates a Software Bill of Materials (SBOM). The SBOM is then uploaded to Cloud One for processing, and a vulnerability report is returned to the CLI user.

This container is to ease the usage of tmas within pipelines. It can fail the pipeline run if a user defined a vulnerability threshold for the image is exceeded.

## Getting Started

1. Clone the repository.

```sh
git clone https://github.com/mawinkler/c1-cs-tmas
```

2. Navigate to the directory.

```sh
cd c1-cs-tmas
```

3. Build the image.

```sh
docker build -t tmas .
```

4. (Optional) Push the image to your registry.

```sh
docker tag tmas registry:yourrepo/tmas:latest
docker push registry:yourrepo/tmas:latest
```

5. Create a scan.

Usage:

```sh
docker run --rm --name tmas \
  -e CLOUD_ONE_API_KEY=<YOUR API KEY HERE> \
  tmas [OPTION...] registry:<YOUR ARTIFACT HERE>
```

Examples:

```sh
docker run --rm --name tmas \
  -e CLOUD_ONE_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxx:xxxxxx... \
  tmas -t medium registry:public.ecr.aws/g1k6g7f0/shell:latest
```

Options        | Description
-------------- | ---------------------------
`-e URL`       | Endpoint to use
`-v`           | Be verbose
`-r REGION`    | Cloud One region to use
`-t THRESHOLD` | <`any`, `critical`, `high`, `medium`, `low`><br>See below
`-u username`  | Username for registry authentication 
`-p password`  | Password for registry authentication 

Threshold   | Description
----------- | --------------------------------
`any`       | Fail if any vulnerability
`critical`  | Fail on critical vulnerabilities
`high`      | Fail on high or higher (default)
`medium`    | Fail on medium or higher
`low`       | Fail on low or higher

If the vulnerability threshold is exceeded the container will exit with exit code `1`.

> ***Note:*** If you need to proxy to Cloud One simply add the documented environment variables to the docker run command.

## AWS CodePipeline Example

Using the tmas container within a pipeline is simple. Here's an example for AWS CodeBuild:

```yaml
  ...
  post_build:
    commands:
      # Create Repository if not exists
      ...
      # Push to ECR
      ...

      # Scan Image using tmas
      - >-
        docker run --cap-drop ALL --rm --name tmas
        -e CLOUD_ONE_API_KEY=${CLOUD_ONE_SCANNER_API_KEY}
        mawinkler/tmas -t medium -u ${ECR_USERNAME} -p ${ECR_PASSWORD} registry:${REPOSITORY_URI}:${TAG} | tee findings.json
      ...

artifacts:
  files:
    - findings.json
```

Full example:

```yaml
---
version: 0.2
phases:
  install:
    commands:
      # Install aws-iam-authenticator and kubectl
      - curl -sS -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.12.7/2019-03-27/bin/linux/amd64/aws-iam-authenticator
      - curl -sS -o kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
      - chmod +x ./kubectl ./aws-iam-authenticator
      - export PATH=${PWD}/:${PATH}

      # Install AWS CLI v2
      - curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o ~/awscliv2.zip
      - unzip -q ~/awscliv2.zip -d ~/
      - ~/aws/install

  pre_build:
    commands:
      # Dynamically set the image name in the deployment manifest
      - TAG=${CODEBUILD_BUILD_NUMBER}
      - echo ${REPOSITORY_URI}:${TAG}
      - sed -i 's@CONTAINER_IMAGE@'"${REPOSITORY_URI}:${TAG}"'@' app-eks.yml
      
      # Set KUBECONFIG
      - export KUBECONFIG=$HOME/.kube/config

  build:
    commands:
      # Login Docker
      - echo ${DOCKER_PASSWORD} | docker login --username ${DOCKER_USERNAME} --password-stdin

      # Check Docker Hub rate limit
      # - TOKEN=$(curl --user "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
      # - echo $(curl --head -H "Authorization:Bearer ${TOKEN}" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest | grep -i rate)
      
      # Build the image
      - docker build --tag ${REPOSITORY_URI}:${TAG} .

      # Login to ECR
      - ECR_USERNAME=AWS
      - ECR_PASSWORD=$(aws ecr get-login-password --region ${AWS_DEFAULT_REGION})
      - >-
        echo ${ECR_PASSWORD} | 
          docker login --username ${ECR_USERNAME} --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com

  post_build:
    commands:
      # Create Repository if not exists
      - >-
        aws ecr describe-repositories --repository-names ${REPOSITORY_URI##*/} ||
        aws ecr create-repository --repository-name ${REPOSITORY_URI##*/} --image-scanning-configuration scanOnPush=true --region ${AWS_DEFAULT_REGION}

      # Push to ECR
      - docker tag ${REPOSITORY_URI}:${TAG} ${REPOSITORY_URI}:latest
      - docker images
      - docker push ${REPOSITORY_URI}:${TAG}
      - docker push ${REPOSITORY_URI}:latest

      # Scan Image using tmas
      - >-
        docker run --cap-drop ALL --rm --name tmas
        -e CLOUD_ONE_API_KEY=${CLOUD_ONE_SCANNER_API_KEY}
        mawinkler/tmas -t medium -u ${ECR_USERNAME} -p ${ECR_PASSWORD} registry:${REPOSITORY_URI}:${TAG} | tee findings.json

      # Assume Role to manage Kubernetes
      - CREDENTIALS=$(aws sts assume-role --role-arn ${EKS_KUBECTL_ROLE_ARN} --role-session-name codebuild-kubectl --duration-seconds 900)
      - export AWS_ACCESS_KEY_ID="$(echo ${CREDENTIALS} | jq -r '.Credentials.AccessKeyId')"
      - export AWS_SECRET_ACCESS_KEY="$(echo ${CREDENTIALS} | jq -r '.Credentials.SecretAccessKey')"
      - export AWS_SESSION_TOKEN="$(echo ${CREDENTIALS} | jq -r '.Credentials.SessionToken')"
      - export AWS_EXPIRATION=$(echo ${CREDENTIALS} | jq -r '.Credentials.Expiration')

      # Update EKS KubeConfig
      - aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME}

      # Deploy to EKS
      - kubectl apply -f app-eks.yml
      - printf '[{"name":"c1-app-sec-uploader","imageUri":"%s"}]' ${REPOSITORY_URI}:${TAG} > build.json


artifacts:
  files:
    - build.json
    - findings.json
```

## Support

This is an Open Source community project. Project contributors may be able to help, depending on their time and availability. Please be specific about what you're trying to do, your system, and steps to reproduce the problem.

For bug reports or feature requests, please [open an issue](../../issues). You are welcome to [contribute](#contribute).

Official support from Trend Micro is not available. Individual contributors may be Trend Micro employees, but are not official support.

## Contribute

I do accept contributions from the community. To submit changes:

1. Fork this repository.
1. Create a new feature branch.
1. Make your changes.
1. Submit a pull request with an explanation of your changes or additions.

I will review and work with you to release the code.
