resource "aws_s3_bucket" "source" {
  bucket = "intercom-survey-app-source"
  acl = "private"
  force_destroy = true
}

resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"
  assume_role_policy = "${file("${path.module}/policies/codepipeline_role.json")}"
}

/* policies */
data "template_file" "codepipeline_policy" {
  template = "${file("${path.module}/policies/codepipeline.json")}"

  vars {
    aws_s3_bucket_arn = "${aws_s3_bucket.source.arn}"
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = "${aws_iam_role.codepipeline_role.id}"
  policy = "${data.template_file.codepipeline_policy.rendered}"
}

/*** CodeBuild ***/
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role"
  assume_role_policy = "${file("${path.module}/policies/codebuild_role.json")}"
}

data "template_file" "codebuld_policy" {
  template = "${file("${path.module}/policies/codebuild_policy.json")}"

  vars {
    aws_s3_bucket_arn = "${aws_s3_bucket.source.arn}"
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "codebuild-policy"
  policy = "${data.template_file.codebuld_policy.rendered}"
  role = "${aws_iam_role.codebuild_role.id}"
}

data "template_file" "buildspec" {
  template = "${file("${path.module}/buildspec.yaml")}"

  vars {
    repository_url = "${var.repository_url}"
    region = "${var.region}"
    cluster_name = "${var.ecs_cluster_name}"
    subnet_id = "${var.run_task_subnet_id}"
    security_group_ids = "${join(",", var.run_task_security_group_ids)}"
  }
}

resource "aws_codebuild_project" "intercom_survey_app_build" {
  "artifacts" {
    type = "CODEPIPELINE"
  }
  "environment" {
    compute_type = "BUILD_GENERAL1_SMALL"
    image = "aws/codebuild/docker:1.12.1"
    type = "LINUX_CONTAINER"
    privileged_mode = true
  }
  name = "intercom-survey-app-build"
  build_timeout = "10"
  service_role = "${aws_iam_role.codebuild_role.arn}"
  "source" {
    type = "CODEPIPELINE"
    buildspec = "${data.template_file.buildspec.rendered}"
  }
}

/*** CodePipeline ***/
resource "aws_codepipeline" "pipeline" {
  "artifact_store" {
    location = "${aws_s3_bucket.source.bucket}"
    type = "S3"
  }
  name = "intercom-survey-app-pipeline"
  role_arn = "${aws_iam_role.codepipeline_role.arn}"
  stage {
    name = "Source"

    action {
      category = "Source"
      name = "Source"
      owner = "ThirdParty"
      provider = "GitHub"
      version = "1"
      output_artifacts = ["source"]

      configuration {
        Owner = "gibbonmi"
        Repo = "dt-intercom-survey-app"
        Branch = "master"
      }
    }
  }
  stage {
    name = "Build"

    action {
      category = "Build"
      name = "Build"
      owner = "AWS"
      provider = "CodeBuild"
      version = "1"
      input_artifacts = ["source"]
      output_artifacts = ["imagedefinitions"]

      configuration {
        ProjectName = "intercom-survey-app-build"
      }
    }
  }
  stage {
    name = "Production"

    action {
      category = "Deploy"
      name = "Deploy"
      owner = "AWS"
      provider = "ECS"
      input_artifacts = ["imagedefinitions"]
      version = "1"

      configuration {
        ClusterName = "${var.ecs_cluster_name}"
        ServiceName = "${var.ecs_service_name}"
        FileName = "imagedefinitions.json"
      }
    }
  }
}