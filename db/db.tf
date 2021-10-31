provider "aws" {
  profile = "default"
  region = "ap-northeast-2"
}

locals {
  svc_nm = "dyheo"
  #pem_file = "dyheo-histech"
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

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 3.0"

  identifier = "dyheo-rds-mysql"

  engine            = "mysql"
  engine_version    = "5.7.19"
  instance_class    = "db.t3.micro"
  allocated_storage = 5

  name     = "dyheo"
  username = "dyheo"
  password = "gjeodud!"
  port     = "3306"

  publicly_accessible = true

  iam_database_authentication_enabled = true

  vpc_security_group_ids = ["${data.aws_security_group.security-group.id}"]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # Enhanced Monitoring - see example for details on how to create the role
  # by yourself, in case you don't want to create it automatically
#  monitoring_interval = "30"
#  monitoring_role_name = "MyRDSMonitoringRole"
#  create_monitoring_role = true

  tags = {
    Creator = "dyheo"
    Environment = "Dev"
    Group = "dyheo-rds"
    Name = "dyheo-rds-mysql"
  }

  # DB subnet group
  #subnet_ids = ["${element(data.aws_subnet.publicx[count.index])}"]
  #subnet_ids = "${tolist("${data.aws_subnet.public[*]}")}"
  #subnet_ids = ["${data.aws_subnet.public[0].id}","${data.aws_subnet.public[1].id}"]
  #subnet_ids = ["${data.aws_subnet.public.*.id}"]
  subnet_ids = data.aws_subnet_ids.public.ids

  # DB parameter group
  family = "mysql5.7"

  # DB option group
  major_engine_version = "5.7"

  # Database Deletion Protection
  #deletion_protection = true
  deletion_protection = false

  parameters = [
    {
      name = "character_set_client"
      value = "utf8mb4"
    },
    {
      name = "character_set_server"
      value = "utf8mb4"
    }
  ]

  options = [
    {
      option_name = "MARIADB_AUDIT_PLUGIN"
      option_settings = [
        {
          name  = "SERVER_AUDIT_EVENTS"
          value = "CONNECT"
        },
        {
          name  = "SERVER_AUDIT_FILE_ROTATIONS"
          value = "37"
        },
      ]
    },
  ]
}

