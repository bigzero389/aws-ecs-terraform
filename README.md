# Terraform AWS ECS blue/green deploy Example
* 사전준비사항  
: AWS IAM 계정이 있어야 한다.  
: EC2 의 key pair 가 있어야 한다.  
: Local PC 에 ~/.ssh 에 key pair pem 파일이 있어야 한다. chmod 600 으로 설정할 것.
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

## 전체 구성
### vpc
* VPC 환경만 구성한다.
* destroy 하면 VPC 가 전체 삭제된다. 이때 vpc terraform 으로 만들어지지 않은 다른 자원들이 종속되어 있으면 삭제가 안된다.
 
## Terraform Script 실행 순서
* vpc => ecs-lb  
  => ecs-cluster(autoscale의 instance 가 연결됨) => ecs-autoscale  
  => ecr => ecs-task(ecr 의 docker 가 연결됨)   
  => ecs-service(lb 의 target_group 과 autoscale instance, ecs-task 가 연결됨)  
  => ecs-codebuild  
  => ecs-codedeploy  
  => ecs-codepipeline(codestart 연결필요)   
  => ecs-route53

### ecs-lb
* 리스너 등록시 blue/green 배포이므로 primary 와 secondary 두개를 동시에 등록하지 말것, blue/green 에서 임의로 변경함.
* 단, blue/green 배포하지 않고 Active-Active 운영하는 경우 둘다 있어야 되는 것으로 추정됨.
* 임의의 test port 는 target group 자체가 정상인지 체크하는 용도로 추정됨. Container 의 포트와 관계없다.

### ecs-codepipeline
* source 를 github 에서 가져오려면 codestar-connections 를 사용해야 하는데 메뉴가 설정에 숨겨져 있다.
* codestar 를 이용한 github 연결은 terraform 으로 안하고 aws web console 에서 했다.

### ecr
* ecr 생성 후 로컬환경에서 ecr 이 정상인지 확인하기 위해서 아래처럼 한다.
* AWS ECR CLI Login 변경 : aws ecr describe-repositories --repository-names "dy" 
* AWS ECR 에 로그인 : aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin [AWS계정].dkr.ecr.ap-northeast-2.amazonaws.com
* 이미지 태그 생성 : docker tag [태그ID] [AWS계정].dkr.ecr.ap-northeast-2.amazonaws.com/dy-helloworld:latest
* 이미지 푸쉬 : docker push [AWS계정].dkr.ecr.ap-northeast-2.amazonaws.com/dy-helloworld:latest
* Permission Deny 나는 경우  
  1. sudo chmod 666 /var/run/docker.sock
  2. sudo usermod -aG docker ${USER}
  3. sudo chmod 666 /var/run/docker.sock
  4. [reference](https://newbedev.com/got-permission-denied-while-trying-to-connect-to-the-docker-daemon-socket-at-unix-var-run-docker-sock-post-http-2fvar-2frun-2fdocker-sock-v1-24-auth-dial-unix-var-run-docker-sock-connect-permission-denied-code-exampl)

 

