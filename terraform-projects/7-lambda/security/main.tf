# IAM Role for Lambda Function
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-execution-role"

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
    Name        = "${var.project_name}-lambda-execution-role"
    Environment = var.environment
  }
}

# Basic Lambda Execution Policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution.name
}

# VPC Access Policy (if Lambda is in VPC)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.lambda_in_vpc ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda_execution.name
}

# Custom IAM Policy for Lambda
resource "aws_iam_policy" "lambda_custom" {
  name        = "${var.project_name}-lambda-custom-policy"
  description = "Custom policy for Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # S3 Access
      var.enable_s3_access ? [{
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          for bucket in var.s3_bucket_arns : "${bucket}/*"
        ]
      }] : [],
      
      # DynamoDB Access
      var.enable_dynamodb_access ? [{
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = var.dynamodb_table_arns
      }] : [],
      
      # SQS Access
      var.enable_sqs_access ? [{
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:SendMessage"
        ]
        Resource = var.sqs_queue_arns
      }] : [],
      
      # SNS Access
      var.enable_sns_access ? [{
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arns
      }] : [],
      
      # Secrets Manager Access
      var.enable_secrets_manager_access ? [{
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.secrets_manager_arns
      }] : [],
      
      # KMS Access
      var.enable_kms_access ? [{
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arns
      }] : []
    )
  })

  tags = {
    Name        = "${var.project_name}-lambda-custom-policy"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "lambda_custom" {
  policy_arn = aws_iam_policy.lambda_custom.arn
  role       = aws_iam_role.lambda_execution.name
}

# Security Group for Lambda (if in VPC)
resource "aws_security_group" "lambda" {
  count       = var.lambda_in_vpc ? 1 : 0
  name_prefix = "${var.project_name}-lambda-"
  vpc_id      = var.vpc_id
  description = "Security group for Lambda function"

  # Outbound rules
  egress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Database access
  dynamic "egress" {
    for_each = var.database_security_groups
    content {
      description     = "Database access"
      from_port       = egress.value.port
      to_port         = egress.value.port
      protocol        = "tcp"
      security_groups = [egress.value.security_group_id]
    }
  }

  tags = {
    Name        = "${var.project_name}-lambda-sg"
    Environment = var.environment
  }
}

# KMS Key for Lambda Environment Variables
resource "aws_kms_key" "lambda" {
  count                   = var.enable_environment_encryption ? 1 : 0
  description             = "KMS key for Lambda environment variables encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda Service"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-lambda-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "lambda" {
  count         = var.enable_environment_encryption ? 1 : 0
  name          = "alias/${var.project_name}-lambda"
  target_key_id = aws_kms_key.lambda[0].key_id
}

# Lambda Function with Security Configuration
resource "aws_lambda_function" "secure" {
  filename         = var.lambda_filename
  function_name    = var.lambda_function_name
  role            = aws_iam_role.lambda_execution.arn
  handler         = var.lambda_handler
  source_code_hash = var.lambda_source_code_hash
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  # Environment variables encryption
  dynamic "environment" {
    for_each = var.environment_variables != null ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  kms_key_arn = var.enable_environment_encryption ? aws_kms_key.lambda[0].arn : null

  # VPC Configuration
  dynamic "vpc_config" {
    for_each = var.lambda_in_vpc ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = [aws_security_group.lambda[0].id]
    }
  }

  # Dead Letter Queue
  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue_arn != null ? [1] : []
    content {
      target_arn = var.dead_letter_queue_arn
    }
  }

  # Tracing
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = {
    Name        = var.lambda_function_name
    Environment = var.environment
  }
}

# Lambda Function URL with Authentication
resource "aws_lambda_function_url" "secure" {
  count              = var.create_function_url ? 1 : 0
  function_name      = aws_lambda_function.secure.function_name
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

# Resource-based Policy for Lambda
resource "aws_lambda_permission" "invoke" {
  count         = length(var.allowed_principals)
  statement_id  = "AllowInvokeFrom${count.index}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.secure.function_name
  principal     = var.allowed_principals[count.index]
  source_arn    = var.source_arns[count.index]
}

data "aws_caller_identity" "current" {}