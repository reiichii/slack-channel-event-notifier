terraform {
  required_version = "= 0.12.3"
}

provider "aws" {
  version = "~> 2.0"
  region  = var.myregion
}

variable "myregion" {
  default = "ap-northeast-1"
}

variable "accountId" {}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_slack_event_lambda"

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

resource "aws_iam_policy" "lambda_logging" {
  name = "lambda_logging"
  path = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn

  depends_on = [
    "aws_iam_policy.lambda_logging"
  ]
}

resource "aws_cloudwatch_log_group" "lambda_function_logs" {
  name              = "/aws/lambda/${aws_lambda_function.notify_lambda.function_name}"
  retention_in_days = 3
}

data "aws_api_gateway_rest_api" "slack_api" {
  name = "slack-api"
}

resource "aws_api_gateway_resource" "slack_event_resource" {
  rest_api_id = data.aws_api_gateway_rest_api.slack_api.id
  parent_id   = data.aws_api_gateway_rest_api.slack_api.root_resource_id
  path_part   = "channel-notifer"
}

resource "aws_api_gateway_method" "slack_event_method" {
  rest_api_id   = data.aws_api_gateway_rest_api.slack_api.id
  resource_id   = aws_api_gateway_resource.slack_event_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "slack_event_integration" {
  rest_api_id             = data.aws_api_gateway_rest_api.slack_api.id
  resource_id             = aws_api_gateway_resource.slack_event_resource.id
  http_method             = aws_api_gateway_method.slack_event_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.myregion}:lambda:path/2015-03-31/functions/${aws_lambda_function.notify_lambda.arn}/invocations"
}

resource "aws_api_gateway_deployment" "slack_event_deployment" {
  rest_api_id = data.aws_api_gateway_rest_api.slack_api.id
  stage_name  = "proto"

  depends_on = [
    "aws_api_gateway_integration.slack_event_integration"
  ]
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.notify_lambda.function_name}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.myregion}:${var.accountId}:${data.aws_api_gateway_rest_api.slack_api.id}/*/${aws_api_gateway_method.slack_event_method.http_method}${aws_api_gateway_resource.slack_event_resource.path}"
}

data "archive_file" "lambda_function" {
  type        = "zip"
  source_dir  = "src/"
  output_path = "lambda.zip"
}

resource "aws_lambda_function" "notify_lambda" {
    filename      = "lambda.zip"
    function_name = "slack-channel-event-notifier"
    role          = aws_iam_role.iam_for_lambda.arn
    handler       = "lambda_function.lambda_handler"
    runtime       = "python3.7"
    environment {
        variables = {
            SLACK_VERIFICATION_TOKEN = "set slack verification token"
            WEB_HOOK_URL             = "set slack webhook url"
        }
    }
    reserved_concurrent_executions = 1

    depends_on = [
        "aws_iam_role_policy_attachment.lambda_logs",
        "data.archive_file.lambda_function"
    ]
}
