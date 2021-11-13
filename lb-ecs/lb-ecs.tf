provider "aws" {
  profile = "default"
  region = "ap-northeast-2"
}

locals {
  svc_nm = "dy"
  creator = "dyheo"
  group = "t-dyheo"

  target_groups = ["primary", "secondary"]
  hosts_name = "dy-ecs.hist-tech.net"
}

## TAG NAME 으로 vpc id 를 가져온다.
data "aws_vpc" "this" {
  filter {
    name = "tag:Name"
    values = ["${local.svc_nm}-vpc"]
  }
}

resource "aws_security_group" "sg-lb-ecs" {
  name   = "${local.svc_nm}-sg-lb-ecs"
  vpc_id = "${data.aws_vpc.this.id}"

  ingress {
    from_port       = 80
    protocol        = "tcp"
    to_port         = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 443
    protocol        = "tcp"
    to_port         = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.svc_nm}-sg-lb-ecs"
    Creator = "${local.creator}"
    Group = "${local.group}"
  }
}

## TAG NAME 으로 subnet 을 가져온다.
data "aws_subnet_ids" "public" {
  vpc_id = "${data.aws_vpc.this.id}"
  filter {
    name = "tag:Name"
    values = ["${local.svc_nm}-sb-public-*"]
  }
}

data "aws_subnet" "public" {
  for_each = data.aws_subnet_ids.public.ids
  id = each.value
}

data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket" "this" {
  bucket        = "${local.svc_nm}-s3-lb-ecs-log"
  acl           = "log-delivery-write"
  force_destroy = true
}

data "aws_iam_policy_document" "s3_bucket_lb_write" {
  policy_id = "s3_bucket_lb_ecs_logs"

  statement {
    actions = [
      "s3:PutObject",
    ]
    effect = "Allow"
    resources = [
      "${aws_s3_bucket.this.arn}/*",
    ]

    principals {
      identifiers = ["${data.aws_elb_service_account.main.arn}"]
      type        = "AWS"
    }
  }

  statement {
    actions = [
      "s3:PutObject"
    ]
    effect = "Allow"
    resources = ["${aws_s3_bucket.this.arn}/*"]
    principals {
      identifiers = ["delivery.logs.amazonaws.com"]
      type        = "Service"
    }
  }

  statement {
    actions = [
      "s3:GetBucketAcl"
    ]
    effect = "Allow"
    resources = ["${aws_s3_bucket.this.arn}"]
    principals {
      identifiers = ["delivery.logs.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.s3_bucket_lb_write.json
}

resource "aws_lb" "this" {
  name               = "${local.svc_nm}-lb-ecs"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.sg-lb-ecs.id}"]
  subnets            = data.aws_subnet_ids.public.ids

  tags = {
    Name = "${local.svc_nm}-lb-ecs"
    Creator = "${local.creator}"
    Group = "${local.group}"
  }
}

resource "aws_lb_target_group" "this" {
  count = "${length(local.target_groups)}"
  name  = "${local.svc_nm}-lb-ecs-tg-${element(local.target_groups, count.index)}"

  port        = 3000
  protocol    = "HTTP"
  vpc_id      = "${data.aws_vpc.this.id}"
  target_type = "instance"

  health_check {
    interval            = 30
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = { 
    Name = "${local.svc_nm}-lb-ecs-tg-${element(local.target_groups, count.index)}"
    Creator = "${local.creator}"
    Group = "${local.group}"
  }
}

data "aws_acm_certificate" "histech_dot_net"   {
  domain   = "*.hist-tech.net"
  statuses = ["ISSUED"]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = "${aws_lb.this.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${data.aws_acm_certificate.histech_dot_net.arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.this.0.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = "${aws_lb.this.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

data "aws_route53_zone" "histech_dot_net" {
  name = "hist-tech.net."
}


resource "aws_route53_record" "this" {
  zone_id = "${data.aws_route53_zone.histech_dot_net.zone_id}"
  #name    = "dyheo-ecs.hist-tech.net"
  name    = local.hosts_name
  type    = "A"

  alias {
    name     = "${aws_lb.this.dns_name}"
    zone_id  = "${aws_lb.this.zone_id}"
    evaluate_target_health = true
  }
}


resource "aws_lb_listener_rule" "this" {
  count        = 2
  listener_arn = "${aws_lb_listener.https.arn}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.this.*.arn[count.index]}"
  }

  condition {
    host_header {
      values = [local.hosts_name]
    }
  }
}
