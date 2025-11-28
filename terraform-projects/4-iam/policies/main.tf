# Custom IAM Policy
resource "aws_iam_policy" "custom" {
  count       = length(var.custom_policies)
  name        = var.custom_policies[count.index].name
  path        = var.custom_policies[count.index].path
  description = var.custom_policies[count.index].description
  policy      = var.custom_policies[count.index].policy

  tags = {
    Name        = var.custom_policies[count.index].name
    Environment = var.environment
  }
}

# S3 Read Only Policy
resource "aws_iam_policy" "s3_readonly" {
  count       = var.create_s3_readonly_policy ? 1 : 0
  name        = "${var.project_name}-s3-readonly"
  path        = "/"
  description = "IAM policy for S3 read-only access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-s3-readonly"
    Environment = var.environment
  }
}

# EC2 Instance Policy
resource "aws_iam_policy" "ec2_instance" {
  count       = var.create_ec2_instance_policy ? 1 : 0
  name        = "${var.project_name}-ec2-instance"
  path        = "/"
  description = "IAM policy for EC2 instance operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeAvailabilityZones",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StopInstances",
          "ec2:StartInstances"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ec2-instance"
    Environment = var.environment
  }
}

# CloudWatch Logs Policy
resource "aws_iam_policy" "cloudwatch_logs" {
  count       = var.create_cloudwatch_logs_policy ? 1 : 0
  name        = "${var.project_name}-cloudwatch-logs"
  path        = "/"
  description = "IAM policy for CloudWatch Logs access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-cloudwatch-logs"
    Environment = var.environment
  }
}

# Lambda Execution Policy
resource "aws_iam_policy" "lambda_execution" {
  count       = var.create_lambda_execution_policy ? 1 : 0
  name        = "${var.project_name}-lambda-execution"
  path        = "/"
  description = "IAM policy for Lambda function execution"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-lambda-execution"
    Environment = var.environment
  }
}