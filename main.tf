terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_dynamodb_table" "url_table" {
  name         = "url-shortener-db"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "short_id"

  attribute {
    name = "short_id"
    type = "S"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "url_shortener_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "url_shortener_lambda_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = [aws_dynamodb_table.url_table.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ==========================================
# 3. LAMBDA FUNCTION CONFIG
# ==========================================
# Python code එක auto zip එකක් බවට පත් කිරීම
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/shortener.py"
  output_path = "${path.module}/shortener.zip"
}

resource "aws_lambda_function" "shortener_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "url-shortener-function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "shortener.handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.url_table.name
    }
  }
}

# ==========================================
# 4. API GATEWAY (REST API)
# ==========================================
resource "aws_api_gateway_rest_api" "url_api" {
  name        = "URLShortenerAPI"
  description = "Serverless URL Shortener Gateway"
}

# Catch-all Resource ({proxy+}) සියලුම රවුට්ස් ලැම්ඩා එකට යවන්න
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.url_api.id
  parent_id   = aws_api_gateway_rest_api.url_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.url_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.url_api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = "ANY"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.shortener_lambda.invoke_arn
}

# Deployment
resource "aws_api_gateway_deployment" "deploy" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.url_api.id
  stage_name  = "prod"
}

# API Gateway එකට Lambda එක run කරන්න දෙන Permission එක
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.shortener_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.url_api.execution_arn}/*/*"
}

# ==========================================
# 5. OUTPUT
# ==========================================
output "api_url" {
  value       = "${aws_api_gateway_deployment.deploy.invoke_url}/shorten"
  description = "URL එක කොට කරන්න මේ ලින්ක් එකට POST Request එකක් එවන්න"
}