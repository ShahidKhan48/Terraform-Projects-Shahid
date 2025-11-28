# Lambda Function
resource "aws_lambda_function" "main" {
  count            = length(var.lambda_functions)
  filename         = var.lambda_functions[count.index].filename
  function_name    = var.lambda_functions[count.index].function_name
  role            = var.lambda_functions[count.index].role_arn
  handler         = var.lambda_functions[count.index].handler
  source_code_hash = var.lambda_functions[count.index].source_code_hash
  runtime         = var.lambda_functions[count.index].runtime
  timeout         = var.lambda_functions[count.index].timeout
  memory_size     = var.lambda_functions[count.index].memory_size
  description     = var.lambda_functions[count.index].description

  dynamic "environment" {
    for_each = var.lambda_functions[count.index].environment_variables != null ? [1] : []
    content {
      variables = var.lambda_functions[count.index].environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = var.lambda_functions[count.index].vpc_config != null ? [var.lambda_functions[count.index].vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.lambda_functions[count.index].dead_letter_config != null ? [var.lambda_functions[count.index].dead_letter_config] : []
    content {
      target_arn = dead_letter_config.value.target_arn
    }
  }

  tags = {
    Name        = var.lambda_functions[count.index].function_name
    Environment = var.environment
  }
}

# Lambda Function from S3
resource "aws_lambda_function" "from_s3" {
  count         = length(var.lambda_functions_from_s3)
  s3_bucket     = var.lambda_functions_from_s3[count.index].s3_bucket
  s3_key        = var.lambda_functions_from_s3[count.index].s3_key
  s3_object_version = var.lambda_functions_from_s3[count.index].s3_object_version
  function_name = var.lambda_functions_from_s3[count.index].function_name
  role         = var.lambda_functions_from_s3[count.index].role_arn
  handler      = var.lambda_functions_from_s3[count.index].handler
  runtime      = var.lambda_functions_from_s3[count.index].runtime
  timeout      = var.lambda_functions_from_s3[count.index].timeout
  memory_size  = var.lambda_functions_from_s3[count.index].memory_size
  description  = var.lambda_functions_from_s3[count.index].description

  dynamic "environment" {
    for_each = var.lambda_functions_from_s3[count.index].environment_variables != null ? [1] : []
    content {
      variables = var.lambda_functions_from_s3[count.index].environment_variables
    }
  }

  tags = {
    Name        = var.lambda_functions_from_s3[count.index].function_name
    Environment = var.environment
  }
}

# Lambda Function URL
resource "aws_lambda_function_url" "main" {
  count              = var.create_function_url ? length(var.lambda_functions) : 0
  function_name      = aws_lambda_function.main[count.index].function_name
  authorization_type = var.function_url_auth_type

  dynamic "cors" {
    for_each = var.function_url_cors != null ? [var.function_url_cors] : []
    content {
      allow_credentials = cors.value.allow_credentials
      allow_headers     = cors.value.allow_headers
      allow_methods     = cors.value.allow_methods
      allow_origins     = cors.value.allow_origins
      expose_headers    = cors.value.expose_headers
      max_age          = cors.value.max_age
    }
  }
}

# Lambda Permission for Function URL
resource "aws_lambda_permission" "function_url" {
  count         = var.create_function_url ? length(var.lambda_functions) : 0
  statement_id  = "AllowExecutionFromFunctionURL"
  action        = "lambda:InvokeFunctionUrl"
  function_name = aws_lambda_function.main[count.index].function_name
  principal     = "*"
  
  function_url_auth_type = var.function_url_auth_type
}