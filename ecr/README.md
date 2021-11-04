# AWS ECR CLI Login 변경
* aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/
* docker login --username AWS -p $(aws ecr get-login-password --region ap-northeast-2) <ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/
* aws ecr describe-repositories --repository-names "dyheo-ecr"

### AWS ECR 에 로그인 한다.
* aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 160270626841.dkr.ecr.ap-northeast-2.amazonaws.com

### Permission Deny 나는 경우
1. sudo chmod 666 /var/run/docker.sock
2. sudo usermod -aG docker ${USER}
3. sudo chmod 666 /var/run/docker.sock
* [reference](https://newbedev.com/got-permission-denied-while-trying-to-connect-to-the-docker-daemon-socket-at-unix-var-run-docker-sock-post-http-2fvar-2frun-2fdocker-sock-v1-24-auth-dial-unix-var-run-docker-sock-connect-permission-denied-code-exampl)

