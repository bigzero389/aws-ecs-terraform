# AWS용 프로바이더 구성
provider "aws" {
  profile = "default"
  region = "ap-northeast-2"
}

locals {
  svc_nm = "dy"
  creator = "dyheo"
  group = "dyheo-dev"
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
