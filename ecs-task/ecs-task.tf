provider "aws" {
  profile = "default"
  region = "ap-northeast-2"
}

locals {
  svc_nm = "dyheo"
  creator = "dyheo"
  group = "t-dyheo"

  pem_file = "dyheo-histech"

  ## EC2 를 만들기 위한 로컬변수 선언
  ami = "ami-0e4a9ad2eb120e054" ## AMAZON LINUX 2
  instance_type = "t2.micro"

  ## Docker Container Port
  container_port = 3000
  memory_reserv = 512
}

data "aws_iam_role" "execution_role" {
  name = "${local.svc_nm}_ecsTaskExecutionRole"
}

data "aws_iam_role" "task_role" {
  name = "${local.svc_nm}_ecsTaskRole"
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${local.svc_nm}-ecs-task"
  execution_role_arn       = "${data.aws_iam_role.execution_role.arn}"
  task_role_arn            = "${data.aws_iam_role.task_role.arn}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  container_definitions    = <<DEFINITION
[
   {
      "portMappings": [
        {
          "hostPort": 0,
          "protocol": "tcp",
          "containerPort": ${local.container_port}
        }
      ],
      "environment": [
        { 
          "name" : "PORT",
          "value": "${local.container_port}" 
        }, {
          "name" : "APP_NAME",
          "value": "${local.svc_nm}"
        }
      ],
      "memoryReservation" : ${local.memory_reserv},
      "image": "160270626841.dkr.ecr.ap-northeast-2.amazonaws.com/helloworld:latest",
      "name": "helloworld"
    }
]
DEFINITION
  tags = {
    Name = "${local.svc_nm}-ecs-task",
    Creator= "${local.creator}",
    Group = "${local.group}"
  }
}
#"image": "gnokoheat/ecs-nodejs-initial:latest",
