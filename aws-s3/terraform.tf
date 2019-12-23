# useful links:
# https://blog.mikeauclair.com/blog/2018/10/16/simple-static-blog-terraform.html

# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 0.12.8" # "~> 0.12.8"

  required_providers {
    aws = ">= 2.26.0" # "~> 2.26.0"
  }
}

# -----------------------------------------------------------------------------

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {}
variable "certificate_domain_name" {}
variable "website_username" {}
variable "website_host" {}

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

data "aws_acm_certificate" "acm_cert" {
  provider    = aws.us-east-1
  domain      = var.certificate_domain_name
  statuses    = ["ISSUED"]
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

# -----------------------------------------------------------------------------

resource "aws_iam_user" "website_admin" {
  name          = var.website_username
  force_destroy = true
}

resource "aws_iam_access_key" "website_admin_access_key" {
  user = aws_iam_user.website_admin.name
}

resource "aws_iam_user_policy" "website_admin_policy" {
  name   = "prod"
  user   = aws_iam_user.website_admin.name
  policy = data.aws_iam_policy_document.website_admin_policy_document.json
}

data "aws_iam_policy_document" "website_admin_policy_document" {
  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "${aws_s3_bucket.website_bucket.arn}",
      "${aws_s3_bucket.website_bucket.arn}/*"
    ]
  }
}

# -----------------------------------------------------------------------------

# bucket for logs
resource "aws_s3_bucket" "website_bucket_logs" {
  bucket        = "logs.${var.website_host}"
  acl           = "log-delivery-write"
  force_destroy = true
}

# bucket for redirects from www
resource "aws_s3_bucket" "website_bucket_www" {
  bucket        = "www.${var.website_host}"
  acl           = "public-read"
  force_destroy = true

  website {
    redirect_all_requests_to = aws_s3_bucket.website_bucket.website_endpoint
  }

  logging {
    # target_bucket = aws_s3_bucket.website_bucket_logs.bucket
    target_bucket = "logs.${var.website_host}"
    target_prefix = "www.${var.website_host}/"
  }
}

# main bucket with files
resource "aws_s3_bucket" "website_bucket" {
  bucket        = var.website_host
  acl           = "public-read"
  force_destroy = true

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  logging {
    target_bucket = aws_s3_bucket.website_bucket_logs.bucket
    target_prefix = "${var.website_host}/"
  }
}

# -----------------------------------------------------------------------------
# folders for logs

resource "aws_s3_bucket_object" "logs_folder_cdn" {
  bucket  = aws_s3_bucket.website_bucket_logs.bucket
  key     = "/cdn.${var.website_host}/"
  content = "/"
}

resource "aws_s3_bucket_object" "logs_folder_www" {
  bucket  = aws_s3_bucket.website_bucket_logs.bucket
  key     = "/www.${var.website_host}/"
  content = "/"
}

resource "aws_s3_bucket_object" "logs_folder_root" {
  bucket  = aws_s3_bucket.website_bucket_logs.bucket
  key     = "/${var.website_host}/"
  content = "/"
}

# -----------------------------------------------------------------------------
# files in bucket

resource "aws_s3_bucket_object" "files" {
  for_each = fileset("${path.module}/bucket", "**/*.*")

  bucket        = aws_s3_bucket.website_bucket.bucket
  key           = each.value
  source        = "${path.module}/bucket/${each.value}"
  etag          = filemd5("${path.module}/bucket/${each.value}")
  content_type  = lookup(var.mime_types, split(".", each.value)[length(split(".", each.value)) - 1])
  acl           = "public-read"
  force_destroy = true
}

# mimetypes map for files in bucket
variable "mime_types" {
  type = map
  default = {
    htm  = "text/html"
    html = "text/html"
    css  = "text/css"
    ttf  = "font/ttf"
    js   = "application/javascript"
    map  = "application/javascript"
    json = "application/json"
  }
}

# -----------------------------------------------------------------------------

resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.bucket
  policy = data.aws_iam_policy_document.website_bucket_policy_document.json
}

data "aws_iam_policy_document" "website_bucket_policy_document" {
  #   policy = <<POLICY
  # {
  #   "Version": "2008-10-17",
  #   "Id": "PolicyForCloudFrontPrivateContent",
  #   "Statement": [
  #     {
  #       "Sid": "1",
  #       "Effect": "Allow",
  #       "Principal": {
  #         "AWS": "${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"
  #       },
  #       "Action": "s3:GetObject",
  #       "Resource": "${aws_s3_bucket.prod.arn}/*"
  #     }
  #   ]
  # }
  # POLICY

  statement {
    sid    = "PublicReadForGetBucketObjects"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.website_bucket.arn}",
      "${aws_s3_bucket.website_bucket.arn}/*"
    ]
  }

  statement {
    sid    = ""
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.website_admin.arn]
    }
    actions = ["s3:*"]
    resources = [
      "${aws_s3_bucket.website_bucket.arn}",
      "${aws_s3_bucket.website_bucket.arn}/*"
    ]
  }
}

# -----------------------------------------------------------------------------

# Create a unique ID for the production S3 bucket - this comes into play if you are routing to multiple sources
locals {
  s3_origin_id = "S3-${aws_s3_bucket.website_bucket.bucket}"
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "access-identity-${aws_s3_bucket.website_bucket.bucket}.s3.amazonaws.com"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  # Disables the distribution instead of deleting it when destroying the resource through Terraform.
  # If this is set, the distribution needs to be deleted manually afterwards.
  # retain_on_delete    = true

  logging_config {
    include_cookies = false
    bucket          = "logs.${var.website_host}.s3.amazonaws.com"
    prefix          = "cdn.${var.website_host}/"
    # bucket          = aws_s3_bucket.website_bucket_logs.bucket
  }

  aliases = ["s3.${var.website_host}"]

  # Simple cache config, and toss all methods but GET and HEAD since we're just reading
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    # Throw these away since they are not needed
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    # viewer_protocol_policy = "allow-all"
    viewer_protocol_policy = "redirect-to-https"

    min_ttl     = 0
    default_ttl = 300 # or 3600
    max_ttl     = 86400
  }

  # US, CA, EU edges only because I'm cheap like that
  price_class = "PriceClass_100"
  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  viewer_certificate {
    # cloudfront_default_certificate = true
    # Use the certificate we imported earlier, and use SNI so that we don't pay for dedicated IPs
    acm_certificate_arn      = data.aws_acm_certificate.acm_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
output "website-console-url" {
  value = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
}

output "website-endpoint-url" {
  value = "http://${aws_s3_bucket.website_bucket_www.website_endpoint}/"
}

output "website-cdn-url" {
  value = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}/"
}

output "website-files" {
  value = fileset("${path.module}/bucket", "**/*.*")
}

# -----------------------------------------------------------------------------

# x-amz-website-redirect-location

# -----------------------------------------------------------------------------
