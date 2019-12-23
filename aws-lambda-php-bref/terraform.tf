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
  default = "eu-central-1" # EU (Frankfurt)
}

variable "api_stage_name" {
  default = "dev"
}

variable "custom_domain_name" {
  default = "example.com"
}

variable "certificate_domain_name" {
  default = "example.com"
}

# -----------------------------------------------------------------------------

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = "us-east-1"
  alias      = "us-east-1"
}

# -----------------------------------------------------------------------------

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "lambda"
  output_path = "lambda.zip"
}

resource "aws_lambda_function" "lambda_function" {
  function_name = "lambda-function"
  role          = aws_iam_role.lambda_role.arn

  filename         = "lambda.zip"
  depends_on       = [data.archive_file.lambda_zip]
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  layers      = ["arn:aws:lambda:eu-central-1:209497400698:layer:php-73-fpm:14"]
  runtime     = "provided"
  handler     = "index.php"
  memory_size = 128 # 1024
  timeout     = 28

  environment {
    variables = {
      foo = "bar"
    }
  }
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

resource "aws_api_gateway_rest_api" "rest-api" {
  name        = "lambda-php"
  description = "Lambda with php example"
}

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.rest-api.id
  resource_id   = aws_api_gateway_rest_api.rest-api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "proxy_wildcard" {
  rest_api_id   = aws_api_gateway_rest_api.rest-api.id
  resource_id   = aws_api_gateway_resource.proxy_wildcard.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_resource" "proxy_wildcard" {
  rest_api_id = aws_api_gateway_rest_api.rest-api.id
  parent_id   = aws_api_gateway_rest_api.rest-api.root_resource_id
  path_part   = "{proxy+}"
}

# -----------------------------------------------------------------------------

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.rest-api.id
  resource_id = aws_api_gateway_method.proxy_root.resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_api_gateway_integration" "lambda_wildcard" {
  rest_api_id = aws_api_gateway_rest_api.rest-api.id
  resource_id = aws_api_gateway_method.proxy_wildcard.resource_id
  http_method = aws_api_gateway_method.proxy_wildcard.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

# -----------------------------------------------------------------------------

resource "aws_api_gateway_deployment" "lambda" {
  depends_on = [
    aws_api_gateway_integration.lambda_root,
    aws_api_gateway_integration.lambda_wildcard
  ]

  rest_api_id = aws_api_gateway_rest_api.rest-api.id
  stage_name  = var.api_stage_name
}

resource "aws_api_gateway_method_settings" "s" {
  rest_api_id = aws_api_gateway_rest_api.rest-api.id
  stage_name  = aws_api_gateway_deployment.lambda.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = false
    logging_level   = "OFF" # set to INFO to enable logging
  }
}

# -----------------------------------------------------------------------------

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  function_name = aws_lambda_function.lambda_function.arn

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_deployment.lambda.execution_arn}/*/*"
}

# -----------------------------------------------------------------------------

data "aws_acm_certificate" "acm_cert" {
  provider    = aws.us-east-1
  domain      = var.certificate_domain_name
  statuses    = ["ISSUED"]
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

# -----------------------------------------------------------------------------

resource "aws_api_gateway_domain_name" "domain" {
  domain_name     = var.custom_domain_name
  certificate_arn = data.aws_acm_certificate.acm_cert.arn
}

resource "aws_api_gateway_base_path_mapping" "base_path" {
  api_id      = aws_api_gateway_rest_api.rest-api.id
  domain_name = aws_api_gateway_domain_name.domain.domain_name
  stage_name  = var.api_stage_name
}

resource "aws_route53_zone" "main" {
  name = var.custom_domain_name
}

resource "aws_route53_record" "a" {
  name    = aws_api_gateway_domain_name.domain.domain_name
  zone_id = aws_route53_zone.main.zone_id
  type    = "A"

  alias {
    evaluate_target_health = false
    name                   = aws_api_gateway_domain_name.domain.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.domain.cloudfront_zone_id
  }
}

# -----------------------------------------------------------------------------

output "name_servers" {
  value = aws_route53_zone.main.name_servers
}

output "url_lambda" {
  # value = "${aws_api_gateway_deployment.lambda.invoke_url}/${aws_api_gateway_resource.proxy_wildcard.path_part}"
  value = aws_api_gateway_deployment.lambda.invoke_url
}

output "url_cloudfront" {
  value = "https://${aws_api_gateway_domain_name.domain.cloudfront_domain_name}/"
}

output "url_custom" {
  value = "https://${var.custom_domain_name}/"
}

# -----------------------------------------------------------------------------
