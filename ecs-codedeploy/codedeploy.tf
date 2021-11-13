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

data "aws_iam_policy_document" "assume_by_codedeploy" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name               = "${local.svc_nm}-ecs-service-codedeploy"
  assume_role_policy = "${data.aws_iam_policy_document.assume_by_codedeploy.json}"
}

data "aws_iam_role" "execution_role" {
  name = "${local.svc_nm}_ecsTaskExecutionRole"
}

data "aws_iam_role" "task_role" {
  name = "${local.svc_nm}_ecsTaskRole"
}

data "aws_ecs_cluster" "selected" {
  cluster_name = "${local.svc_nm}-ecs-cluster"
}

data "aws_iam_policy_document" "task_role" {
  statement {
    sid    = "AllowDescribeCluster"
    effect = "Allow"

    actions = ["ecs:DescribeClusters"]

    resources = ["${data.aws_ecs_cluster.selected.arn}"]
  }
}

data "aws_iam_policy_document" "codedeploy" {
  statement {
    sid    = "AllowLoadBalancingAndECSModifications"
    effect = "Allow"

    actions = [
      "ecs:CreateTaskSet",
      "ecs:DeleteTaskSet",
      "ecs:DescribeServices",
      "ecs:UpdateServicePrimaryTaskSet",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyRule",
      "lambda:InvokeFunction",
      "cloudwatch:DescribeAlarms",
      "sns:Publish",
      "s3:GetObject",
      "s3:GetObjectMetadata",
      "s3:GetObjectVersion"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowPassRole"
    effect = "Allow"

    actions = ["iam:PassRole"]

    resources = [
      "${data.aws_iam_role.execution_role.arn}",
      "${data.aws_iam_role.task_role.arn}",
    ]
  }
}

resource "aws_iam_role_policy" "codedeploy" {
  role   = "${aws_iam_role.codedeploy.name}"
  policy = "${data.aws_iam_policy_document.codedeploy.json}"
}

resource "aws_codedeploy_app" "this" {
  compute_platform = "ECS"
  name             = "${local.svc_nm}-ecs-service-deploy"
}

data "aws_ecs_service" "selected" {
  service_name = "${local.svc_nm}-ec2-ecs-service"
  cluster_arn = data.aws_ecs_cluster.selected.arn
}

data "aws_lb" "selected" {
  name = "${local.svc_nm}-lb-ecs"
}

data "aws_lb_listener" "selected80" {
  load_balancer_arn = data.aws_lb.selected.arn
  port = 80
}

data "aws_lb_target_group" "blue" {
  name = "${local.svc_nm}-lb-ecs-tg-primary"
}

data "aws_lb_target_group" "green" {
  name = "${local.svc_nm}-lb-ecs-tg-secondary"
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name               = "${aws_codedeploy_app.this.name}"
  deployment_group_name  = "${local.svc_nm}-ecs-service-deploy-group"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = "${aws_iam_role.codedeploy.arn}"

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 60
    }
  }

  ecs_service {
    cluster_name = "${data.aws_ecs_cluster.selected.cluster_name}"
    service_name = "${data.aws_ecs_service.selected.service_name}"
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = ["${data.aws_lb_listener.selected80.arn}"]
      }

      target_group {
        name = "${data.aws_lb_target_group.blue.name}"
      }

      target_group {
        name = "${data.aws_lb_target_group.green.name}"
      }
    }
  }
}
