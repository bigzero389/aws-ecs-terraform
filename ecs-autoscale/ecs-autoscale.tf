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
  ## 반드시 메모리 2G 이상 할당해야 됨.
  instance_type = "t3.medium"
}

data "aws_vpc" "this" {
  filter {
    name = "tag:Name"
    values = ["${local.svc_nm}-vpc"]
  }
}

data "aws_ami" "latest-ecs" {
  most_recent = true
  owners      = ["591542846629"] # Amazon

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*"]
    #values = ["*amazon-ecs-optimized"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_iam_policy_document" "ecs-instance-policy" {
  statement {
    actions = ["sts:AssumeRole"] ## 권한을 잠시 빌린다.  

    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs-instance-role" {
  name = "${local.svc_nm}_ecs-instance-role"
  path = "/"
  assume_role_policy = "${data.aws_iam_policy_document.ecs-instance-policy.json}"
}

resource "aws_iam_role_policy_attachment" "ecs-instance-role-attachment" {
  role = "${aws_iam_role.ecs-instance-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs-instance-profile" {
  name = "${local.svc_nm}_ecs-instance-profile"
  path = "/"
  role = "${aws_iam_role.ecs-instance-role.id}"
}

data "aws_security_group" "sg-lb-ecs" {
  vpc_id = "${data.aws_vpc.this.id}"
  filter {
    name = "tag:Name"
    values = ["${local.svc_nm}-sg-lb-ecs"]
  }
}

data "aws_security_group" "sg-core" {
  vpc_id = "${data.aws_vpc.this.id}"
  filter {
    name = "tag:Name"
    values = ["${local.svc_nm}-sg-core"]
  }
}

resource "aws_launch_configuration" "this" {
  name                 = "${local.svc_nm}-launch-config"
  image_id             = "${data.aws_ami.latest-ecs.id}"
  #image_id             = "${local.ami}"
  instance_type        = "${local.instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.ecs-instance-profile.id}"

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 100
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }

  security_groups             = [
    "${data.aws_security_group.sg-lb-ecs.id}",
    "${data.aws_security_group.sg-core.id}"
  ]
  associate_public_ip_address = "true"
  key_name                    = "${local.pem_file}"
  user_data                   = <<EOF
#!/bin/bash
# ECS Cluster 와 이름이 같아야 한다.
echo ECS_CLUSTER=${local.svc_nm}-ecs-cluster>> /etc/ecs/ecs.config
#sudo yum update -y ## too long time
EOF
}

data "aws_subnet_ids" "public" {
  vpc_id = "${data.aws_vpc.this.id}"
  filter {
    name = "tag:Name"
    values = ["${local.svc_nm}-sb-public-*"]
  } 
}

resource "aws_autoscaling_group" "this" {
  name = "${local.svc_nm}-ecs-instance-service"
  max_size = 2
  min_size = 1
  desired_capacity = 1
  #vpc_zone_identifier = data.aws_subnet.private.*.id
  vpc_zone_identifier = tolist(data.aws_subnet_ids.public.ids)
  launch_configuration = "${aws_launch_configuration.this.name}"
  health_check_type = "ELB"

  tag {
    key = "Name"
    value = "${local.svc_nm}-ecs-autoscale-instance"
    #value               = "ECS-Instance-${local.svc_nm}-service"
    propagate_at_launch = true
  }
}
