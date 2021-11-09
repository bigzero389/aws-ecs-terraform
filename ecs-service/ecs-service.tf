provider "aws" {
  profile = "default"
  region = "ap-northeast-2"
}

locals {
  svc_nm = "dy"
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

data "aws_ecs_task_definition" "this" {
  task_definition = "${local.svc_nm}-ecs-task"
}

data "aws_ecs_cluster" "this" {
  cluster_name = "${local.svc_nm}-ecs-cluster"
}

data "aws_alb_target_group" "selected" {
  name = "${local.svc_nm}-alb-tg"
}

data "aws_alb" "selected" {
  name = "${local.svc_nm}-alb"
}

data "aws_alb_listener" "selected80" {
  load_balancer_arn = data.aws_alb.selected.arn
  port = 80
}

resource "aws_ecs_service" "this" {
  name            = "${local.svc_nm}-ec2-ecs-service"
  task_definition = "${data.aws_ecs_task_definition.this.id}"
  cluster         = "${data.aws_ecs_cluster.this.arn}"

  load_balancer {
    #target_group_arn = "${data.aws_alb_target_group.this.0.arn}"
    target_group_arn = "${data.aws_alb_target_group.selected.arn}"
    #container_name   = "${local.svc_nm}"
    container_name   = "dy-helloworld"
    container_port   = "${local.container_port}"
  }

  launch_type                        = "EC2"
  desired_count                      = 1
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  depends_on = [data.aws_alb_listener.selected80]

}
