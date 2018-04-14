variable "aws_region" {
  default = "eu-west-1"
}

# lambda function variables

variable "lambda_archive_file" {
  default = "lambda.zip"
}

variable "lambda_function_name" {
  default = "Executor"
}

variable "lambda_runtime" {
  default = "nodejs8.10"
}

variable "lambda_handler" {
  default = "Executor.handler"
}

variable "lambda_timeout" {
  default = 5
}

# bucket variables

variable "bucket_name" {
  default = "executor-bucket"
}

variable "lambda_function_bucket_name" {
  default = "lambda.zip"
}

# state machine variables

variable "step_function_definition_file" {
  default = "step-function.json"
}

variable "step_function_name" {
  default = "StepFunctionWorkflow"
}


