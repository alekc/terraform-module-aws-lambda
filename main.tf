####### IAM #######
data "aws_iam_policy_document" "AWSLambdaTrustPolicy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "terraform_function_role" {
  name               = "${var.app_name}-role-${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.AWSLambdaTrustPolicy.json
}

resource "aws_iam_role_policy_attachment" "terraform_lambda_policy" {
  role       = aws_iam_role.terraform_function_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

####### Lambda #######
resource "random_string" "random_name" {
  count   = var.app_name == "" ? 1 : 0
  length  = 5
  special = false
  upper   = true
  lower   = false
}

resource "aws_lambda_function" "lambda" {
  filename      = var.file_path
  function_name = "${var.app_name}-${terraform.workspace}"
  role          = aws_iam_role.terraform_function_role.arn
  handler       = var.lambda_handler

  source_code_hash = filebase64sha256(var.file_path)

  runtime     = var.lambda_runtime
  publish     = var.lambda_publish
  memory_size = var.lambda_memory
  timeout     = var.lambda_timeout

  dynamic "environment" {
    for_each = local.environment_map
    content {
      variables = environment.value
    }
  }
}
locals {
  // this ugliesh hack is needed because otherwise in case there are no
  // default environments, it will fail with Error: At least one field is expected inside environment
  // see https://github.com/hashicorp/terraform-provider-aws/issues/1110 for details
  environment_map = var.lambda_environment == null ? [] : [var.lambda_environment]
  app_name        = var.app_name == "" ? "${random_string.random_name[0].result}-${terraform.workspace}" : "${var.app_name}-${terraform.workspace}"
}

####### Api Gateway #######
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = local.app_name
  protocol_type = var.api_gateway_protocol_type
  target        = aws_lambda_function.lambda.arn
}

resource "aws_lambda_permission" "lambda_api_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}

locals {
  enable_custom_domain = var.custom_domain_name == "" || var.certificate_arn == "" ? 0 : 1
}

resource "aws_apigatewayv2_domain_name" "lambda" {
  count       = local.enable_custom_domain
  domain_name = var.custom_domain_name

  domain_name_configuration {
    certificate_arn = var.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

output "api_target_hostname" {
  value = local.enable_custom_domain == 0 ? "" : aws_apigatewayv2_domain_name.lambda[0].domain_name_configuration[0].target_domain_name
}

resource "aws_apigatewayv2_api_mapping" "example" {
  count       = local.enable_custom_domain
  api_id      = aws_apigatewayv2_api.lambda_api.id
  domain_name = aws_apigatewayv2_domain_name.lambda[0].id
  stage       = "$default"
}

####### Outputs #######
output "endpoint" {
  value = aws_apigatewayv2_api.lambda_api.api_endpoint
}
