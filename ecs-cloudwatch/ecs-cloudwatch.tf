provider "aws" {
  profile = "default"
  region = "ap-northeast-2"
}

locals {
  svc_nm = "dy"
  creator = "dyheo"
  group = "t-dyheo"
}

resource "aws_cloudwatch_log_group" "this" {
  name = "/aws/ecs/dy-helloworld"

  tags = {
    Environment = "t-dyheo"
    Application = "bigzeroHelloWorld"
    Name = "${local.svc_nm}-ecs-task",
    Creator= "${local.creator}",
    Group = "${local.group}"
  }
}
