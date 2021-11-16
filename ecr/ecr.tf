# AWS용 프로바이더 구성 
provider "aws" { 
  profile = "default" 
  region = "ap-northeast-2" 
} 
 
locals { 
  svc_nm = "dy" 
  creator = "dyheo" 
  group = "t-dyheo" 
}

resource "aws_ecr_repository" "this" {
  name                 = "${local.svc_nm}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${local.svc_nm}-helloworld-ecr",
    Creator= "${local.creator}",
    Group = "${local.group}"
  } 
}

