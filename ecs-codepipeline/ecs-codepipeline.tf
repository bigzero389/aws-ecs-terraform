provider "aws" {
  profile = "default"
  region = "ap-northeast-2"
}

locals { 
  svc_nm = "dy"
  creator = "dyheo"
  group = "t-dyheo"

  github_token = ""
  #github_owner = "garack@gmail.com"
  github_owner = "largezero"
  github_repo = "HelloBigzeroWorldNode"
  github_branch = "main"
}

resource "aws_s3_bucket" "pipeline" {
  bucket = "${local.svc_nm}-ecs-codepipeline-bucket"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "${local.svc_nm}Codepipeline",
  "Statement": [
        {
            "Sid": "DenyUnEncryptedObjectUploads",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${local.svc_nm}-ecs-codepipeline-bucket/*",
            "Condition": {
                "StringNotEquals": {
                    "s3:x-amz-server-side-encryption": "aws:kms"
                }
            }
        },
        {
            "Sid": "DenyInsecureConnections",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": "arn:aws:s3:::${local.svc_nm}-ecs-codepipeline-bucket/*",
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
}
POLICY
}

data "aws_iam_policy_document" "assume_by_pipeline" {
  statement {
    sid = "AllowAssumeByPipeline"
    effect = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "pipeline" {
  name = "${local.svc_nm}_pipeline-ecs-service-role"
  assume_role_policy = "${data.aws_iam_policy_document.assume_by_pipeline.json}"
}

data "aws_iam_policy_document" "pipeline" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "ecr:DescribeImages",
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision",
      "codestar-connections:UseConnection",
      "elasticbeanstalk:*",
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "cloudwatch:*",
      "s3:*",
      "sns:*",
      "cloudformation:*",
      "rds:*",
      "sqs:*",
      "ecs:*",
      "opsworks:*",
      "devicefarm:*",
      "servicecatalog:*",
      "iam:PassRole"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "pipeline" {
  role = "${aws_iam_role.pipeline.name}"
  policy = "${data.aws_iam_policy_document.pipeline.json}"
}

## codestar connection 사용함. 권한 필요함.
data "aws_codestarconnections_connection" "selected" {
  arn = "arn:aws:codestar-connections:ap-northeast-2:160270626841:connection/84283fa2-d4a1-4c74-a05f-6cebb9620101"
}

resource "aws_codepipeline" "this" {
  name = "${local.svc_nm}-ecs-pipeline"
  role_arn = "${aws_iam_role.pipeline.arn}"

  artifact_store {
    location = "${local.svc_nm}-ecs-codepipeline-bucket"
    type = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        #ConnectionArn        = var.codestar_connection_arn
        ConnectionArn        = data.aws_codestarconnections_connection.selected.arn
        #FullRepositoryId     = "${var.github_organization}/${var.github_repository}"
        FullRepositoryId     = "largezero/HelloBigzeroWorldNode"
        #BranchName           = var.github_branch
        BranchName           = "main"
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
    #action {
    #  name = "Source"
    #  category = "Source"
    #  owner = "ThirdParty"
    #  provider = "GitHub"
    #  version = "1"
    #  output_artifacts = ["SourceArtifact"]

    #  configuration = {
    #    OAuthToken = "${local.github_token}"
    #    Owner = "${local.github_owner}"
    #    Repo = "${local.github_repo}"
    #    Branch = "${local.github_branch}"
    #  }
    #}
  }

  stage {
    name = "Build"

    action {
      name = "Build"
      category = "Build"
      owner = "AWS"
      provider = "CodeBuild"
      version = "1"
      input_artifacts = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = "${local.svc_nm}-ecs-codebuild"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name = "ExternalDeploy"
      category = "Deploy"
      owner = "AWS"
      provider = "CodeDeployToECS"
      input_artifacts = ["BuildArtifact"]
      version = "1"

      configuration = {
        ApplicationName = "${local.svc_nm}-ecs-service-codedeploy"
        #ApplicationName = "${local.svc_nm}-helloworld"
        DeploymentGroupName = "${local.svc_nm}-ecs-service-deploy-group"
        TaskDefinitionTemplateArtifact = "BuildArtifact"
        TaskDefinitionTemplatePath = "taskdef.json"
        AppSpecTemplateArtifact = "BuildArtifact"
        AppSpecTemplatePath = "appspec.yml"
      }
    }
  }
}
