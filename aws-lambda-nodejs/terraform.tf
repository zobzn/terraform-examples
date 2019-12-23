terraform {
  required_version = ">= 0.12.15"
  required_providers {
    archive = ">= 1.3.0"
    aws     = ">= 2.40.0"
  }
}

# -----------------------------------------------------------------------------

variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "eu-central-1" # EU (Frankfurt)
}

# -----------------------------------------------------------------------------

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

# -----------------------------------------------------------------------------

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda/index.js"
  output_path = "lambda.zip"
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket        = "zbz-lambda-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_object" "lambda_bucket_object" {
  key           = "lambda.zip"
  bucket        = aws_s3_bucket.lambda_bucket.bucket
  source        = data.archive_file.lambda_zip.output_path
  force_destroy = true
}

resource "aws_lambda_function" "lambda_function" {
  function_name = "lambda-function"
  role          = aws_iam_role.lambda_role.arn

  s3_bucket = aws_s3_bucket.lambda_bucket.bucket
  s3_key    = aws_s3_bucket_object.lambda_bucket_object.key

  runtime = "nodejs12.x"
  handler = "index.handler"
  # timeout = "50"
  # memory_size = var.memory_size

  # environment {
  #   variables = var.env_vars
  # }
}

resource "aws_iam_policy" "lambda_policy" {
  name = "lambda-policy"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "*"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = ""
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_role_policy" {
  name = "lambda-role-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "*"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_role_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# -----------------------------------------------------------------------------

resource "aws_api_gateway_rest_api" "lambda-elb-test-lambda" {
  name        = "lambda-elb-test"
  description = "Lambda vs Elastic Beanstalk Lambda Example"
}

resource "aws_api_gateway_method_settings" "s" {
  rest_api_id = aws_api_gateway_rest_api.lambda-elb-test-lambda.id
  stage_name  = aws_api_gateway_deployment.lambda.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = false
    logging_level   = "OFF" # set to INFO to enable logging
  }
}

resource "aws_api_gateway_resource" "question" {
  rest_api_id = aws_api_gateway_rest_api.lambda-elb-test-lambda.id
  parent_id   = aws_api_gateway_rest_api.lambda-elb-test-lambda.root_resource_id
  path_part   = "question"
}

resource "aws_api_gateway_method" "question" {
  rest_api_id   = aws_api_gateway_rest_api.lambda-elb-test-lambda.id
  resource_id   = aws_api_gateway_resource.question.id
  http_method   = "ANY"
  authorization = "NONE"
}

# -----------------------------------------------------------------------------

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.lambda-elb-test-lambda.id
  resource_id = aws_api_gateway_method.question.resource_id
  http_method = aws_api_gateway_method.question.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_api_gateway_deployment" "lambda" {
  depends_on = [
    aws_api_gateway_integration.lambda
  ]

  rest_api_id = aws_api_gateway_rest_api.lambda-elb-test-lambda.id
  stage_name  = "test"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.arn
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_deployment.lambda.execution_arn}/*/*"
}

# -----------------------------------------------------------------------------

output "url" {
  value = "${aws_api_gateway_deployment.lambda.invoke_url}/${aws_api_gateway_resource.question.path_part}"
}

# -----------------------------------------------------------------------------
