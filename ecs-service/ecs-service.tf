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

data "aws_vpc" "this" {
  filter {
    name = "tag:Name"
    values = ["${local.svc_nm}-vpc"]
  }
}

data "aws_ecs_task_definition" "this" {
  #task_definition = "${local.svc_nm}-ecs-task"
  task_definition = "${local.svc_nm}"
}

data "aws_ecs_cluster" "this" {
  cluster_name = "${local.svc_nm}-ecs-cluster"
}

data "aws_lb_target_group" "blue" {
  name = "${local.svc_nm}-lb-ecs-tg-primary"
}

data "aws_lb_target_group" "green" {
  name = "${local.svc_nm}-lb-ecs-tg-secondary"
}

#data "aws_lb_target_group" "selected" {
#  #name = "${local.svc_nm}-lb-ecs-tg-*"
#  filter {
#    name   = "Name"
#    values = "${local.svc_nm}-lb-ecs-tg-*"
#  }
#}

data "aws_lb" "selected" {
  name = "${local.svc_nm}-lb-ecs"
}

data "aws_lb_listener" "selected80" {
  load_balancer_arn = data.aws_lb.selected.arn
  port = 80
}

resource "aws_ecs_service" "this" {
  name            = "${local.svc_nm}-ec2-ecs-service"
  task_definition = "${data.aws_ecs_task_definition.this.id}"
  cluster         = "${data.aws_ecs_cluster.this.arn}"

  load_balancer {
    #target_group_arn = data.aws_lb_target_group.this.*.arn[0]
    target_group_arn = data.aws_lb_target_group.blue.arn
    #target_group_arn = "${data.aws_lb_target_group.this.0.arn}"
    #target_group_arn = "${data.aws_lb_target_group.selected.arn}"
    #container_name   = "${local.svc_nm}"
    container_name   = "dy"
    container_port   = "${local.container_port}"
  }

  launch_type                        = "EC2"
  desired_count                      = 1
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  depends_on = [data.aws_lb_listener.selected80]

}
