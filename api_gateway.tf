# API Gateway

resource "aws_api_gateway_rest_api" "alternate_api" {
  name        = "Serverless API"
  description = "Alternate API based on Serverless computing"
}

# Resource and method (accept any resource and HTTP verb and send the resource to the backend)
# See https://docs.aws.amazon.com/es_es/apigateway/latest/developerguide/api-gateway-create-api-as-simple-proxy-for-http.html

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.alternate_api.id
  parent_id   = aws_api_gateway_rest_api.alternate_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.alternate_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

# Integration (routing): Ties resource/method to Lambda function

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.alternate_api.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

# Special case: when path is empty

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.alternate_api.id
  resource_id   = aws_api_gateway_rest_api.alternate_api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.alternate_api.id
  resource_id = aws_api_gateway_method.proxy_root.resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

# Final step: Deploy and expose API

resource "aws_api_gateway_deployment" "alternate_api" {
  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration.lambda_root
  ]

  rest_api_id = aws_api_gateway_rest_api.alternate_api.id
  stage_name  = "alternate"

  provisioner "local-exec" {
    command = "echo ${aws_api_gateway_deployment.alternate_api.invoke_url} > python-lambda/base_url"
  }

  provisioner "local-exec" {
    command = "sed -Ei.bak \"s#(alternateUrl:)[^,]*,#\\1 '$(cat python-lambda/base_url)',#\" node/config.js"
  }
}