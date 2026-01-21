# ==============================================================================
# Terraform Configuration for Point Cloud Annotator
# AWS Serverless Backend: S3 + CloudFront + API Gateway + Lambda + DynamoDB
# ==============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  resource_prefix = "${var.project_name}-${var.environment}"
}

# ==============================================================================
# DynamoDB Table for Annotations
# ==============================================================================

resource "aws_dynamodb_table" "annotations" {
  name           = "${local.resource_prefix}-annotations"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "uuid"

  attribute {
    name = "uuid"
    type = "S"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ==============================================================================
# IAM Role for Lambda Functions
# ==============================================================================

resource "aws_iam_role" "lambda_role" {
  name = "${local.resource_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "${local.resource_prefix}-lambda-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.annotations.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ==============================================================================
# Lambda Functions
# ==============================================================================

# Package Lambda functions
data "archive_file" "get_annotations" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/get_annotations"
  output_path = "${path.module}/dist/get_annotations.zip"
}

data "archive_file" "save_annotation" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/save_annotation"
  output_path = "${path.module}/dist/save_annotation.zip"
}

data "archive_file" "delete_annotation" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/delete_annotation"
  output_path = "${path.module}/dist/delete_annotation.zip"
}

# Get Annotations Lambda
resource "aws_lambda_function" "get_annotations" {
  filename         = data.archive_file.get_annotations.output_path
  function_name    = "${local.resource_prefix}-get-annotations"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.get_annotations.output_base64sha256
  runtime          = "nodejs20.x"
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.annotations.name
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Save Annotation Lambda
resource "aws_lambda_function" "save_annotation" {
  filename         = data.archive_file.save_annotation.output_path
  function_name    = "${local.resource_prefix}-save-annotation"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.save_annotation.output_base64sha256
  runtime          = "nodejs20.x"
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.annotations.name
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Delete Annotation Lambda
resource "aws_lambda_function" "delete_annotation" {
  filename         = data.archive_file.delete_annotation.output_path
  function_name    = "${local.resource_prefix}-delete-annotation"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.delete_annotation.output_base64sha256
  runtime          = "nodejs20.x"
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.annotations.name
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ==============================================================================
# API Gateway
# ==============================================================================

resource "aws_api_gateway_rest_api" "api" {
  name        = "${local.resource_prefix}-api"
  description = "Point Cloud Annotator API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# /annotations resource
resource "aws_api_gateway_resource" "annotations" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "annotations"
}

# GET /annotations
resource "aws_api_gateway_method" "get_annotations" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.annotations.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_annotations" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.annotations.id
  http_method             = aws_api_gateway_method.get_annotations.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_annotations.invoke_arn
}

# POST /annotations
resource "aws_api_gateway_method" "post_annotations" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.annotations.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_annotations" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.annotations.id
  http_method             = aws_api_gateway_method.post_annotations.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.save_annotation.invoke_arn
}

# DELETE /annotations
resource "aws_api_gateway_method" "delete_annotations" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.annotations.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "delete_annotations" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.annotations.id
  http_method             = aws_api_gateway_method.delete_annotations.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.delete_annotation.invoke_arn
}

# OPTIONS /annotations (CORS preflight)
resource "aws_api_gateway_method" "options_annotations" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.annotations.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_annotations" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.annotations.id
  http_method = aws_api_gateway_method.options_annotations.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_annotations" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.annotations.id
  http_method = aws_api_gateway_method.options_annotations.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_annotations" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.annotations.id
  http_method = aws_api_gateway_method.options_annotations.http_method
  status_code = aws_api_gateway_method_response.options_annotations.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.options_annotations]
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "get_annotations" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_annotations.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "save_annotation" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.save_annotation.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "delete_annotation" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_annotation.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.annotations.id,
      aws_api_gateway_method.get_annotations.id,
      aws_api_gateway_method.post_annotations.id,
      aws_api_gateway_method.delete_annotations.id,
      aws_api_gateway_method.options_annotations.id,
      aws_api_gateway_integration.get_annotations.id,
      aws_api_gateway_integration.post_annotations.id,
      aws_api_gateway_integration.delete_annotations.id,
      aws_api_gateway_integration.options_annotations.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "prod"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ==============================================================================
# S3 Bucket for Static Website
# ==============================================================================

resource "aws_s3_bucket" "website" {
  bucket = "${local.resource_prefix}-website-${random_id.bucket_suffix.hex}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontAccess"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })
}

# ==============================================================================
# CloudFront Distribution
# ==============================================================================

resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${local.resource_prefix}-oac"
  description                       = "OAC for Point Cloud Annotator Website"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "Point Cloud Annotator Website"

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "S3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Custom error response for SPA routing
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


