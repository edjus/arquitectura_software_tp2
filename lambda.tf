# Role needed for Lambda resource

resource "aws_iam_role" "iam_for_lambda" {
    name = "iam_for_lambda"

    assume_role_policy = <<EOF
{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                    "Service": "lambda.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
}
EOF
}

# Lambda function

resource "aws_lambda_function" "lambda_function" {
    filename        = "python-lambda/lambda.zip"
    function_name   = "getValue"
    role            = aws_iam_role.iam_for_lambda.arn
    handler         =  "lambda.execute"
    runtime         = "python3.6"
}

# Permission for API Gateway to invoke our function

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.alternate_api.execution_arn}/*/*"
}