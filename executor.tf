# defining aws region

provider "aws" {
  region = "${var.aws_region}"
}

# defining policies for aws s3 read and write access

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

resource "aws_iam_policy" "s3-access" {
    name = "s3-access"
    path = "/"
    policy = "${data.aws_iam_policy_document.s3-access.json}"
}

# defining aws roles and policies for a lambda function

data "aws_iam_policy_document" "lambda-assume-role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda-exec" {
  name = "lambda-exec-role"
  assume_role_policy = "${data.aws_iam_policy_document.lambda-assume-role.json}"
}

resource "aws_iam_role_policy_attachment" "lambda-exec" {
    role       = "${aws_iam_role.lambda-exec.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "s3-access" {
    role       = "${aws_iam_role.lambda-exec.name}"
    policy_arn = "${aws_iam_policy.s3-access.arn}"
}

# defining aws roles and policies for a step functions state machine

data "aws_iam_policy_document" "sfn-assume-role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["states.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sfn-exec" {
  name = "sfn-exec"
  assume_role_policy = "${data.aws_iam_policy_document.sfn-assume-role.json}"
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

resource "aws_iam_policy" "lambda-invoke" {
    name = "lambda-invoke"
    policy = "${data.aws_iam_policy_document.lambda-invoke.json}"
}

resource "aws_iam_role_policy_attachment" "lambda-invoke" {
    role       = "${aws_iam_role.sfn-exec.name}"
    policy_arn = "${aws_iam_policy.lambda-invoke.arn}"
}

# creating an aws s3 bucket

resource "aws_s3_bucket" "lambda-bucket" {
  bucket = "${var.bucket_name}"
}

# adding the lambda archive to the defined bucket

resource "aws_s3_bucket_object" "lambda-package" {
  bucket = "${aws_s3_bucket.lambda-bucket.bucket}"
  key    = "${var.lambda_function_bucket_name}"
  source = "${var.lambda_archive_file}"
  etag   = "${md5(file(var.lambda_archive_file))}"
  depends_on = ["aws_s3_bucket.lambda-bucket"]
}

# defining aws lambda function

resource "aws_lambda_function" "lambda-function" {
  function_name = "${var.lambda_function_name}"

  s3_bucket = "${aws_s3_bucket_object.lambda-package.bucket}"
  s3_key    = "${aws_s3_bucket_object.lambda-package.key}"

  handler = "${var.lambda_handler}"
  runtime = "${var.lambda_runtime}"
  timeout= "${var.lambda_timeout}"

  role = "${aws_iam_role.lambda-exec.arn}"
}

# defining aws step functions state machine

resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "${var.step_function_name}"
  role_arn = "${aws_iam_role.sfn-exec.arn}"

  definition = "${data.template_file.sfn-definition.rendered}"
}

# step function definition template

data "template_file" "sfn-definition" {
  template = "${file(var.step_function_definition_file)}"

  vars {
    lambda-arn = "${aws_lambda_function.lambda-function.arn}"
  }
}
