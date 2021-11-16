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

data "aws_lb" "selected" {
  name = "${local.svc_nm}-lb-ecs"
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
    name     = "${data.aws_lb.selected.dns_name}"
    zone_id  = "${data.aws_lb.selected.zone_id}"
    evaluate_target_health = true
  }
}


