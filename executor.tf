# reading aws region from variables file

provider "aws" {
  region = "${var.aws_region}"
}

# defining aws roles and policies

data "aws_iam_policy_document" "assume-role-lambda" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "assume-role-sfn" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["states.${var.aws_region}.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "s3-access" {
    statement {
        actions = [
            "s3:GetObject",
            "s3:PutObject",
        ]
        resources = [
            "arn:aws:s3:::*",
        ]
    }
}

data "aws_iam_policy_document" "lambda-invoke" {
    statement {
        actions = [
            "lambda:InvokeFunction"
        ]
        resources = [
            "*",
        ]
    }
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda_exec"
  assume_role_policy = "${data.aws_iam_policy_document.assume-role-lambda.json}"
}

resource "aws_iam_role_policy_attachment" "basic-exec-role" {
    role       = "${aws_iam_role.lambda_exec.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "s3-access" {
    name = "s3-access"
    path = "/"
    policy = "${data.aws_iam_policy_document.s3-access.json}"
}

resource "aws_iam_role_policy_attachment" "s3-access" {
    role       = "${aws_iam_role.lambda_exec.name}"
    policy_arn = "${aws_iam_policy.s3-access.arn}"
}


resource "aws_iam_role" "state-machine-exec" {
  name = "state_machine_exec"
  assume_role_policy = "${data.aws_iam_policy_document.assume-role-sfn.json}"
}

resource "aws_iam_policy" "lambda-invoke" {
    name = "lambda-invoke"
    policy = "${data.aws_iam_policy_document.lambda-invoke.json}"
}

resource "aws_iam_role_policy_attachment" "lambda-invoke" {
    role       = "${aws_iam_role.state-machine-exec.name}"
    policy_arn = "${aws_iam_policy.lambda-invoke.arn}"
}


# creating an aws s3 bucket

resource "aws_s3_bucket" "montage-hyperflow-bucket" {
  bucket = "montage-hyperflow-bucket"
}

# adding the lambda archive to the defined bucket

resource "aws_s3_bucket_object" "lambda_package" {
  bucket = "${aws_s3_bucket.montage-hyperflow-bucket.bucket}"
  key    = "hyperflowHandler.zip"
  source = "${var.lambda_archive_file}"
  etag   = "${md5(file(var.lambda_archive_file))}"
}

# defining aws lambda function

resource "aws_lambda_function" "hyperflow_lambda" {
  function_name = "HyperflowLambdaHandler3"

  s3_bucket = "${aws_s3_bucket_object.lambda_package.bucket}"
  s3_key    = "${aws_s3_bucket_object.lambda_package.key}"

  handler = "HyperflowExecutor.handler"
  runtime = "nodejs8.10"
  timeout=15

  role = "${aws_iam_role.lambda_exec.arn}"
}

# defining aws step functions step machine

resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "my-state-machine"
  role_arn = "${aws_iam_role.state-machine-exec.arn}"

  definition = "${data.template_file.sfn-definition.rendered}"
}

# step function definition template

data "template_file" "sfn-definition" {
  template = "${file("step-function.json")}"

  vars {
    lambda-arn = "${aws_lambda_function.hyperflow_lambda.arn}"
  }
}
