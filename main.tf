terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.48"
    }
  }
  required_version = ">= 1.3"
}

provider "aws" {
  profile = "tur"
  region  = "us-east-1"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_apigatewayv2_api" "MyApiGatewayHTPPApi" {
  name          = "Terraform API Gateway HTTP API to Event bridge"
  protocol_type = "HTTP"
  body = jsonencode({
    "openapi" : "3.0.1",
    "info" : {
      "title" : "API Gateway HTTP API to Event bridge"
    },
    "paths" : {
      "/" : {
        "post" : {
          "responses" : {
            "default" : {
              "description" : "EventBridge response!"
            }
          },
          "x-amazon-apigateway-integration" : {
            "integrationSubType" : "EventBridge-PutEvents",
            "credentials" : "${aws_iam_role.APIGWRole.arn}",
            "requestParameters" : {
              "Detail" : "$request.body.Detail",
              "DetailType" : "MyDetailType",
              "Source" : "demo.apigw"
            },
            "payloadFormatVersion" : "1.0",
            "type" : "aws_proxy",
            "connectionType" : "INTERNET"
          }
        }
      }
    }
  })
}

resource "aws_apigatewayv2_stage" "MyApiGatewayHTPPApiStage" {
  api_id = aws_apigatewayv2_api.MyApiGatewayHTPPApi.id
  name   = "default"
  #   auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.MyLogGroup2.arn
    format          = "$context.requestId $context.extendedRequestId"
  }
}

# Creating an IAM role for API Gateway
resource "aws_iam_role" "APIGWRole" {
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "apigateway.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

# Creating an IAM policy for API Gateway to write to create an EventBridge event
resource "aws_iam_policy" "APIGWPolicy" {
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "events:PutEvents",
        "Resource" : "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "APIGWPolicyAttachment" {
  role       = aws_iam_role.APIGWRole.name
  policy_arn = aws_iam_policy.APIGWPolicy.arn
}

resource "aws_cloudwatch_event_rule" "MyEventRule" {
  event_pattern = jsonencode({
    "account" : ["${data.aws_caller_identity.current.account_id}"],
    "source" : ["demo.apigw"]
  })
}

resource "aws_cloudwatch_event_target" "MyRuleTarget" {
  arn  = aws_lambda_function.MyLambdaFunction.arn
  rule = aws_cloudwatch_event_rule.MyEventRule.id
}

data "archive_file" "LambdaZipFile" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/LambdaFunction.zip"
}


resource "aws_lambda_function" "MyLambdaFunction" {
  function_name    = "apigw-http-eventbridge-terraform-demo-${data.aws_caller_identity.current.account_id}"
  filename         = data.archive_file.LambdaZipFile.output_path
  source_code_hash = filebase64sha256(data.archive_file.LambdaZipFile.output_path)
  role             = aws_iam_role.LambdaRole.arn
  handler          = "LambdaFunction.handler"
  runtime          = "nodejs16.x"
}

resource "aws_lambda_permission" "EventBridgeLambdaPermission" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.MyLambdaFunction.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.MyEventRule.arn
}

resource "aws_iam_role" "LambdaRole" {
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "LambdaPolicy" {
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:aws/lambda/${aws_lambda_function.MyLambdaFunction.function_name}:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "LambdaPolicyAttachment" {
  role       = aws_iam_role.LambdaRole.name
  policy_arn = aws_iam_policy.LambdaPolicy.arn
}

resource "aws_cloudwatch_log_group" "MyLogGroup2" {
  name              = "/aws/lambda/${aws_lambda_function.MyLambdaFunction.function_name}"
  retention_in_days = 14
}

output "APIGW-URL" {
  value       = aws_apigatewayv2_api.MyApiGatewayHTPPApi.api_endpoint
  description = "The API Gateway Invoke URL"
}

output "LambdaFunctionName" {
  value       = aws_lambda_function.MyLambdaFunction.function_name
  description = "The Lambda function name"
}

output "CloudWatchLogName" {
  value       = "/aws/lambda/${aws_lambda_function.MyLambdaFunction.function_name}"
  description = "The Lambda function log group"
}
