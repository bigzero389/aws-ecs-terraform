provider "aws" {
  profile = "default"
  region  = "ap-northeast-2"
}

locals {
  svc_nm  = "dy"
  creator = "dyheo"
  group   = "t-dyheo"

  target_groups = ["primary", "secondary"]
  hosts_name    = "dy-ecs.hist-tech.net"
  domain_name   = "dy-search-domain"
}

## TAG NAME 으로 vpc id 를 가져온다.
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["${local.svc_nm}-vpc"]
  }
}

data "aws_subnet_ids" "public" {
  vpc_id = data.aws_vpc.selected.id

  filter {
    name   = "tag:Name"
    values = ["${local.svc_nm}-sb-public-*"]
  }
}

data "aws_subnet" "public" {
  for_each = data.aws_subnet_ids.public.ids
  id       = each.value
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_security_group" "es" {
  name        = "${local.svc_nm}-sg-search"
  description = "Hello bigzero world opensearch"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    #cidr_blocks      = ["0.0.0.0/0"]
    cidr_blocks = [
      data.aws_vpc.selected.cidr_block,
      "125.177.68.23/32",
      "211.206.114.80/32"
    ]
  }

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    cidr_blocks = [
      "125.177.68.23/32",
      "211.206.114.80/32",
      data.aws_vpc.selected.cidr_block
    ]
  }

  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
      description      = "outbound all"
    }
  ]

  tags = {
    Name    = "${local.svc_nm}-sg-search",
    Creator = local.creator,
    Group   = local.group
  }
}

#resource "aws_iam_service_linked_role" "es" {
#  aws_service_name = "es.amazonaws.com"
#}

resource "aws_elasticsearch_domain" "es" {
  domain_name           = local.domain_name
  elasticsearch_version = "6.8" ## 2021.11.25 latest

  cluster_config {
    instance_type          = "t3.medium.elasticsearch"
    zone_awareness_enabled = true
    instance_count         = length(data.aws_subnet.public)
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }

  #encrypt_at_rest {
  #  enabled = var.encrypt_at_rest_enabled
  #}

  #domain_endpoint_options {
  #  enforce_https       = true
  #  tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  #}

  vpc_options {
    #subnet_ids = [
    #  data.aws_subnet_ids.selected.ids[0],
    #  data.aws_subnet_ids.selected.ids[1],
    #]
    subnet_ids         = data.aws_subnet_ids.public.ids
    security_group_ids = [aws_security_group.es.id]
  }

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
    "indices.fielddata.cache.size"           = ""
  }

  access_policies = <<CONFIG
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "es:*",
            "Principal": "*",
            "Effect": "Allow",
            "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${local.domain_name}/*"
        }
    ]
}
CONFIG

  tags = {
    Domain  = local.domain_name
    Name    = "${local.svc_nm}-search",
    Creator = local.creator,
    Group   = local.group
  }

  #depends_on = [aws_iam_service_linked_role.es]
}

resource "aws_iam_role" "firehose_role" {
  name = "${local.svc_nm}-firehose_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "firehose-elasticsearch" {
  name   = "elasticsearch"
  role   = aws_iam_role.firehose_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "es:*"
      ],
      "Resource": [
        "${aws_elasticsearch_domain.es.arn}",
        "${aws_elasticsearch_domain.es.arn}/*"
      ]
        },
        {
          "Effect": "Allow",
          "Action": [
            "ec2:DescribeVpcs",
            "ec2:DescribeVpcAttribute",
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeNetworkInterfaces",
            "ec2:CreateNetworkInterface",
            "ec2:CreateNetworkInterfacePermission",
            "ec2:DeleteNetworkInterface"
          ],
          "Resource": [
            "*"
          ]
        }
  ]
}
EOF
}

resource "aws_s3_bucket" "bucket" {
  bucket = "${local.svc_nm}-firehose-bucket"
  acl    = "private"
}

resource "aws_kinesis_firehose_delivery_stream" "this" {
  depends_on = [aws_iam_role_policy.firehose-elasticsearch]

  name        = "${local.svc_nm}-kinesis-firehose-es"
  destination = "elasticsearch"

  s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.bucket.arn
  }
  elasticsearch_configuration {
    domain_arn = aws_elasticsearch_domain.es.arn
    role_arn   = aws_iam_role.firehose_role.arn
    index_name = "${local.svc_nm}-logs"
    type_name  = "Logs"

    vpc_config {
      #subnet_ids         = [aws_subnet.first.id, aws_subnet.second.id]
      subnet_ids         = data.aws_subnet_ids.public.ids
      security_group_ids = [aws_security_group.es.id]
      role_arn           = aws_iam_role.firehose_role.arn
    }
  }
}
