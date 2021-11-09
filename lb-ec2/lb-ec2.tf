# AWS용 프로바이더 구성
## reference site : https://rampart81.github.io/post/lb_terraform/
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
  instance_type = "t3.micro"

## Application Service Port
  service_port = 3000
}

## TAG NAME 으로 vpc id 를 가져온다.
data "aws_vpc" "this" {
  filter {
    name = "tag:Name"
    values = ["${local.svc_nm}-vpc"]
  }
}

resource "aws_security_group" "sg-lb-ec2" {
  name = "${local.svc_nm}-sg-lb-ec2"
  description = "ec2 server 80/443 service test"
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
    Name = "${local.svc_nm}-sg-lb-ec2"
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
  bucket        = "${local.svc_nm}-s3-alb-ec2-log"
  acl           = "log-delivery-write"
  force_destroy = true
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

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.s3_bucket_lb_write.json
}

resource "aws_lb" "public" {
  name               = "${local.svc_nm}-lb-ec2"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg-lb-ec2.id]
  subnets            = data.aws_subnet_ids.public.ids

  ## 임의로 삭제 가능여부 
  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.this.bucket
    prefix  = "${local.svc_nm}-lb-ec2-public"
    enabled = true
  }

  tags = {
    Name = "${local.svc_nm}-lb-ec2"
    Creator = "${local.creator}"
    Group = "${local.group}"
  }
}

data "aws_instances" "target_instance" {
  filter {
    name = "tag:Name"
    values = ["${local.svc_nm}-ec2-*"]
  }
}

resource "aws_lb_target_group" "public" {
  name     = "${local.svc_nm}-lb-ec2-tg"
  port     = local.service_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.this.id

  health_check {
    interval            = 30
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = { 
    Name = "${local.svc_nm}-lb-tg-ec2-public"
    Creator = "${local.creator}"
    Group = "${local.group}"
  }
}

resource "aws_lb_target_group_attachment" "public" {
  count = length(tolist(data.aws_instances.target_instance.ids))
  target_group_arn = aws_lb_target_group.public.arn
  target_id        = element(tolist(data.aws_instances.target_instance.ids), count.index)
  port             = local.service_port
}

data "aws_acm_certificate" "histech_dot_net"   { 
  #domain   = "*.example.com."
  domain   = "*.hist-tech.net"
  statuses = ["ISSUED"]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = "${aws_lb.public.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${data.aws_acm_certificate.histech_dot_net.arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.public.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = "${aws_lb.public.arn}"
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


resource "aws_route53_record" "public_dyheo" {
  zone_id = "${data.aws_route53_zone.histech_dot_net.zone_id}"
  name    = "dyheo-ec2.hist-tech.net"
  type    = "A"

  alias {
    name     = "${aws_lb.public.dns_name}"
    zone_id  = "${aws_lb.public.zone_id}"
    evaluate_target_health = true
  }
}
