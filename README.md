# AWS 를 이용한 Terraform Example
* 사전준비사항  
: AWS IAM 계정이 있어야 한다.  
: EC2 의 key pair 가 있어야 한다.  
: Local PC 에 ~/.ssh 에 key pair pem 파일이 있어야 한다.  
: Local PC 에 Terraform 이 설치되어 있어야 한다.  

## Terraform 기본 사용법
```
terraform init
terraform validate
terraform plan 
terraform apply [--auto-approve]
terraform destroy [--auto-approve]
```
* 테라폼 파일을 정해진 폴더에 만든다. 확장자는 tf 이다.
* tf 파일이 있는 경로에서 terraform init 를 실행한다. .terraform 숨김폴더가 생성된다.
* terraform validate 를 하여 문법적인 오류를 확인한다.
* terraform plan 을 하면 처리할 계획을 만들어서 보여준다. 지정된 변수등이 정확히 나오는지 확인한다.
* terraform apply 를 하면 스크립트가 실행된다. yes 를 입력하여 실행할지 여부를 이중 체크한다.
* terraform destroy 하면 해당 자원을 모두 삭제한다.

## 폴더구성
### vpc
* VPC 환경만 구성한다.
* 기본적인 네트워크 환경들도 구성한다. 즉, all 에서 EC2 만 제외하고 구성된다.
* destroy 하면 VPC 가 전체 삭제된다. 이때 vpc terraform 으로 만들어지지 않은 다른 자원들이 종속되어 있으면 삭제가 안된다.
* 위에 all 에서 변경해야 되는 부분들을 변경하고 실행한다.

## AWS ECR 작업
### AWS ECR CLI Login 변경
* aws ecr describe-repositories --repository-names "dy-helloworld" 

### AWS ECR 에 로그인 한다.  
* aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin [AWS계정].dkr.ecr.ap-northeast-2.amazonaws.com

### 이미지 태그 생성.
* docker tag [태그ID] [AWS계정].dkr.ecr.ap-northeast-2.amazonaws.com/dy-helloworld:latest

### 이미지 푸쉬
* docker push [AWS계정].dkr.ecr.ap-northeast-2.amazonaws.com/dy-helloworld:latest

### Permission Deny 나는 경우
1. sudo chmod 666 /var/run/docker.sock
2. sudo usermod -aG docker ${USER}
3. sudo chmod 666 /var/run/docker.sock
* [reference](https://newbedev.com/got-permission-denied-while-trying-to-connect-to-the-docker-daemon-socket-at-unix-var-run-docker-sock-post-http-2fvar-2frun-2fdocker-sock-v1-24-auth-dial-unix-var-run-docker-sock-connect-permission-denied-code-exampl)

### 순서
* vpc => ecr => lb-ecs
      => ecs-cluster(autoscale의 instance 가 연결됨) => ecs-autoscale
      => ecs-task(ecr 의 docker 가 연결됨) 
      => ecs-service(lb 의 target_group 과 autoscale instance, ecs-task 가 연결됨)
      => ecs-codebuild 
      => ecs-codedeploy 
      => ecs-codepipeline(codestart 연결필요) 
      => ecs-route53
