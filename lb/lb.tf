# AWS용 프로바이더 구성
## reference site : https://rampart81.github.io/post/lb_terraform/
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
}

## TAG NAME 으로 vpc id 를 가져온다.
data "aws_vpc" "this" {
  filter {
    name = "tag:Name"
    values = ["${local.svc_nm}-vpc"]
  }
}

## TAG NAME 으로 security group 을 가져온다.
data "aws_security_group" "security-group" {
  vpc_id = "${data.aws_vpc.this.id}"
  filter {
    name = "tag:Name"
    values = ["${local.svc_nm}-sg"]
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
  bucket        = "${local.svc_nm}-s3-alb-log"
  acl           = "log-delivery-write"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.s3_bucket_lb_write.json
}

resource "aws_alb" "public" {
  name               = "${local.svc_nm}-alb"
  internal           = false
  load_balancer_type = "application"
  #security_groups    = [aws_security_group.lb_sg.id]
  security_groups    = [data.aws_security_group.security-group.id]
  subnets            = data.aws_subnet_ids.public.ids

  ## 임의로 삭제 가능여부 
  #enable_deletion_protection = true
  enable_deletion_protection = false

  access_logs {
    #bucket  = aws_s3_bucket.lb_logs.bucket
    bucket  = aws_s3_bucket.this.bucket
    prefix  = "${local.svc_nm}-alb-public"
    enabled = true
  }

  tags = {
    Name = "${local.svc_nm}-alb"
    Creator = "${local.creator}"
    Group = "${local.group}"
  }
}

data "aws_iam_policy_document" "s3_bucket_lb_write" {
  policy_id = "s3_bucket_lb_logs"

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

data "aws_instances" "target_instance" {
  filter {
    name = "tag:Name"
    values = ["${local.svc_nm}-ec2-*"]
  }
}

resource "aws_alb_target_group" "public" {
  name     = "${local.svc_nm}-alb-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.this.id

  health_check {
    interval            = 30
    path                = "/examples/index.jsp"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = { 
    Name = "${local.svc_nm}-alb-tg-public"
    Creator = "${local.creator}"
    Group = "${local.group}"
  }
}

#resource "aws_alb_target_group" "static" {
#  name     = "static-target-group"
#  port     = 8080
#  protocol = "HTTP"
#  vpc_id   = "${aws_default_vpc.dmz.id}"
#
#  health_check {
#    interval            = 30
#    path                = "/ping"
#    healthy_threshold   = 3
#    unhealthy_threshold = 3
#  }
#
#  tags { Name = "Static Target Group" }
#}

resource "aws_alb_target_group_attachment" "public" {
  count = length(tolist(data.aws_instances.target_instance.ids))
  target_group_arn = aws_alb_target_group.public.arn
  target_id        = element(tolist(data.aws_instances.target_instance.ids), count.index)
  port             = 8080
}

#resource "aws_alb_target_group_attachment" "static" {
#  target_group_arn = "${aws_alb_target_group.static.arn}"
#  target_id        = "${aws_instance.static.id}"
#  port             = 8080
#}

data "aws_acm_certificate" "histech_dot_net"   { 
  #domain   = "*.example.com."
  domain   = "*.hist-tech.net"
  statuses = ["ISSUED"]
}

resource "aws_alb_listener" "https" {
  load_balancer_arn = "${aws_alb.public.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${data.aws_acm_certificate.histech_dot_net.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.public.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = "${aws_alb.public.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
#    target_group_arn = "${aws_alb_target_group.public.arn}"
#    type             = "forward"
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

#resource "aws_alb_listener_rule" "static" {
#  listener_arn = "${aws_alb_listener.https.arn}"
#  priority     = 100
#
#  action {
#    type             = "forward"
#    target_group_arn = "${aws_alb_target_group.static.arn}"
#  }
#
#  condition {
#    field  = "path-pattern"
#    values = ["/static/*"]
#  }
#}

#resource "aws_alb_listener_rule" "redirect_http_to_https" {
#  listener_arn = aws_alb_listener.http.arn
#
#  action {
#    type = "redirect"
#
#    redirect {
#      port        = "443"
#      protocol    = "HTTPS"
#      status_code = "HTTP_301"
#    }
#  }
#
#  condition {
#    http_header {
#      http_header_name = "scheme"
#      values           = 
#    }
#  }
#}

data "aws_route53_zone" "histech_dot_net" {
  name = "hist-tech.net."
}


resource "aws_route53_record" "public_dyheo" {
  zone_id = "${data.aws_route53_zone.histech_dot_net.zone_id}"
  name    = "dyheo-test.hist-tech.net"
  type    = "A"

  alias {
    name     = "${aws_alb.public.dns_name}"
    zone_id  = "${aws_alb.public.zone_id}"
    evaluate_target_health = true
  }
}
