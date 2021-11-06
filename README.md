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
### all
* VPC 를 구성하고 EC2 를 한대 만든다.
* destroy 하면 VPC 및 EC2 등 모든 자원이 삭제된다.

* 아래 "svc_nm"과 "pem_file" 을 적절한 값으로 변경한다.
```
 ...
 12 locals {
 13   ## 신규 VPC 를 구성하는 경우 svc_nm 과 pem_file 를 새로 넣어야 한다.
 14   svc_nm = "dyheo"
 15   pem_file = "dyheo-histech-2"
 ...
```
* 아래 cidr_blocks 에 본인이 ssh 로 접속할 공인IP 로 변경한다.
```
161     {
162       description      = "SSH from home"
163       from_port        = 22
164       to_port          = 22
165       protocol         = "tcp"
166       type             = "ssh"
167       cidr_blocks      = ["125.177.68.23/32", "211.206.114.80/32"]
168       ipv6_cidr_blocks = ["::/0"]
169       prefix_list_ids  = []
170       security_groups  = []
171       self = false
172     }

```

### vpc
* VPC 환경만 구성한다.
* 기본적인 네트워크 환경들도 구성한다. 즉, all 에서 EC2 만 제외하고 구성된다.
* destroy 하면 VPC 가 전체 삭제된다. 이때 vpc terraform 으로 만들어지지 않은 다른 자원들이 종속되어 있으면 삭제가 안된다.
* 위에 all 에서 변경해야 되는 부분들을 변경하고 실행한다.

### ec2
* 지정된 tag 이름으로 만들어진 VPC 정보에 기반하여 EC2 만 생성한다. 
* destroy 하면 해당 EC2 를 삭제한다.

* 아래 부분을 자기 환경에 맞는 값으로 수정해서 실행한다.
```
 7 locals {
  8   svc_nm = "dyheo"
  9   pem_file = "dyheo-histech-2"
```
[terraform example reference](https://github.com/largezero/ecs-with-codepipeline-example-by-terraform).  
* aws cli 를 이용하여 ami list 가져오기
```
aws ec2 describe-images \ 
--filters Name=architecture,Values=x86_64 Name=name,Values="amzn2-ami-ecs-hvm-*"
```

## AWS ECR 작업
### AWS ECR CLI Login 변경
* aws ecr describe-repositories --repository-names "dyheo-ecr" 

### AWS ECR 에 로그인 한다.  
* aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 160270626841.dkr.ecr.ap-northeast-2.amazonaws.com

### 이미지 태그 생성.
docker tag 74472d168358 160270626841.dkr.ecr.ap-northeast-2.amazonaws.com/helloworld:latest

### 이미지 푸쉬
docker push 160270626841.dkr.ecr.ap-northeast-2.amazonaws.com/helloworld:latest

### Permission Deny 나는 경우
1. sudo chmod 666 /var/run/docker.sock
2. sudo usermod -aG docker ${USER}
3. sudo chmod 666 /var/run/docker.sock
* [reference](https://newbedev.com/got-permission-denied-while-trying-to-connect-to-the-docker-daemon-socket-at-unix-var-run-docker-sock-post-http-2fvar-2frun-2fdocker-sock-v1-24-auth-dial-unix-var-run-docker-sock-connect-permission-denied-code-exampl)

