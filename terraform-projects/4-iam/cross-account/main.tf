# Cross-Account IAM Role
resource "aws_iam_role" "cross_account" {
  name = "${var.project_name}-cross-account-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_account_arns
        }
        Condition = var.assume_role_conditions
      }
    ]
  })

  max_session_duration = var.max_session_duration

  tags = {
    Name        = "${var.project_name}-cross-account-role"
    Environment = var.environment
  }
}

# Cross-Account Policy
resource "aws_iam_policy" "cross_account" {
  name        = "${var.project_name}-cross-account-policy"
  description = "Policy for cross-account access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = var.cross_account_policy_statements
  })

  tags = {
    Name        = "${var.project_name}-cross-account-policy"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "cross_account" {
  role       = aws_iam_role.cross_account.name
  policy_arn = aws_iam_policy.cross_account.arn
}

# External ID for additional security
resource "random_string" "external_id" {
  count   = var.use_external_id ? 1 : 0
  length  = 32
  special = false
}

# Cross-Account Role with External ID
resource "aws_iam_role" "cross_account_with_external_id" {
  count = var.use_external_id ? 1 : 0
  name  = "${var.project_name}-cross-account-external-id-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_account_arns
        }
        Condition = merge(
          var.assume_role_conditions,
          {
            StringEquals = {
              "sts:ExternalId" = random_string.external_id[0].result
            }
          }
        )
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-cross-account-external-id-role"
    Environment = var.environment
    ExternalId  = random_string.external_id[0].result
  }
}

# Cross-Account S3 Bucket Policy
resource "aws_s3_bucket_policy" "cross_account" {
  count  = var.create_cross_account_s3_policy ? 1 : 0
  bucket = var.s3_bucket_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CrossAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_account_arns
        }
        Action = var.s3_allowed_actions
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
        Condition = var.s3_access_conditions
      }
    ]
  })
}

# Cross-Account KMS Key Policy
resource "aws_kms_key" "cross_account" {
  count                   = var.create_cross_account_kms_key ? 1 : 0
  description             = "KMS key for cross-account access"
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
        Sid    = "Allow cross-account access"
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_account_arns
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = var.kms_access_conditions
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-cross-account-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "cross_account" {
  count         = var.create_cross_account_kms_key ? 1 : 0
  name          = "alias/${var.project_name}-cross-account"
  target_key_id = aws_kms_key.cross_account[0].key_id
}

# Cross-Account SNS Topic Policy
resource "aws_sns_topic_policy" "cross_account" {
  count = var.create_cross_account_sns_policy ? 1 : 0
  arn   = var.sns_topic_arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CrossAccountSNSAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_account_arns
        }
        Action = [
          "sns:Publish",
          "sns:Subscribe",
          "sns:Receive"
        ]
        Resource = var.sns_topic_arn
        Condition = var.sns_access_conditions
      }
    ]
  })
}

# Cross-Account Lambda Permission
resource "aws_lambda_permission" "cross_account" {
  count         = var.create_cross_account_lambda_permission ? 1 : 0
  statement_id  = "AllowCrossAccountInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = var.trusted_account_id
  source_arn    = var.lambda_source_arn
}

# Cross-Account ECR Repository Policy
resource "aws_ecr_repository_policy" "cross_account" {
  count      = var.create_cross_account_ecr_policy ? 1 : 0
  repository = var.ecr_repository_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CrossAccountECRAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_account_arns
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

data "aws_caller_identity" "current" {}