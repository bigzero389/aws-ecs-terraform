# AWS용 프로바이더 구성
provider "aws" {
  profile = "default"
  region = "ap-northeast-2"
}

locals {
  svc_nm = "dyheo"
  creator = "dyheo"
  group = "dyheo-dev"

  pem_file = "dyheo-histech"

  ## EC2 를 만들기 위한 로컬변수 선언
  ami = "ami-0e4a9ad2eb120e054" ## AMAZON LINUX 2
  instance_type = "t2.micro"
}

resource "aws_s3_bucket" "s3" {
  bucket = "${local.svc_nm}-s3"
  acl    = "private"

  tags = {
    Name = "${local.svc_nm}-s3",
    Creator = "${local.creator}",
    Group = "${local.group}"
  }
}
