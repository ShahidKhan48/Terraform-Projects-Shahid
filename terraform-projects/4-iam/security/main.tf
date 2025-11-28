# IAM Password Policy
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = var.minimum_password_length
  require_lowercase_characters   = var.require_lowercase_characters
  require_numbers               = var.require_numbers
  require_uppercase_characters   = var.require_uppercase_characters
  require_symbols               = var.require_symbols
  allow_users_to_change_password = var.allow_users_to_change_password
  max_password_age              = var.max_password_age
  password_reuse_prevention     = var.password_reuse_prevention
  hard_expiry                   = var.hard_expiry
}

# IAM Access Analyzer
resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "${var.project_name}-access-analyzer"
  type         = var.analyzer_type

  dynamic "configuration" {
    for_each = var.analyzer_type == "ORGANIZATION" ? [1] : []
    content {
      unused_access {
        unused_access_age = var.unused_access_age
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-access-analyzer"
    Environment = var.environment
  }
}

# CloudTrail for IAM API Logging
resource "aws_cloudtrail" "iam_audit" {
  count                         = var.enable_iam_cloudtrail ? 1 : 0
  name                          = "${var.project_name}-iam-audit-trail"
  s3_bucket_name               = aws_s3_bucket.cloudtrail[0].bucket
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_log_file_validation   = true

  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = []

    data_resource {
      type   = "AWS::IAM::Role"
      values = ["arn:aws:iam::*:role/*"]
    }

    data_resource {
      type   = "AWS::IAM::User"
      values = ["arn:aws:iam::*:user/*"]
    }
  }

  tags = {
    Name        = "${var.project_name}-iam-audit-trail"
    Environment = var.environment
  }
}

# S3 Bucket for CloudTrail
resource "aws_s3_bucket" "cloudtrail" {
  count         = var.enable_iam_cloudtrail ? 1 : 0
  bucket        = "${var.project_name}-iam-cloudtrail-${random_string.bucket_suffix[0].result}"
  force_destroy = var.force_destroy_cloudtrail_bucket

  tags = {
    Name        = "${var.project_name}-iam-cloudtrail"
    Environment = var.environment
  }
}

resource "random_string" "bucket_suffix" {
  count   = var.enable_iam_cloudtrail ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

# IAM Role for Security Auditing
resource "aws_iam_role" "security_auditor" {
  name = "${var.project_name}-security-auditor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.security_auditor_principals
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.security_auditor_external_id
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-security-auditor-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "security_auditor_readonly" {
  role       = aws_iam_role.security_auditor.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "security_auditor_security" {
  role       = aws_iam_role.security_auditor.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

# IAM Role for Break Glass Access
resource "aws_iam_role" "break_glass" {
  count = var.create_break_glass_role ? 1 : 0
  name  = "${var.project_name}-break-glass-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.break_glass_principals
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.break_glass_external_id
          }
          IpAddress = {
            "aws:SourceIp" = var.break_glass_allowed_ips
          }
        }
      }
    ]
  })

  max_session_duration = 3600  # 1 hour max

  tags = {
    Name        = "${var.project_name}-break-glass-role"
    Environment = var.environment
    Purpose     = "EmergencyAccess"
  }
}

resource "aws_iam_role_policy_attachment" "break_glass_admin" {
  count      = var.create_break_glass_role ? 1 : 0
  role       = aws_iam_role.break_glass[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# CloudWatch Alarms for IAM Security Events
resource "aws_cloudwatch_log_metric_filter" "root_usage" {
  count          = var.enable_iam_monitoring ? 1 : 0
  name           = "${var.project_name}-root-usage"
  log_group_name = aws_cloudwatch_log_group.cloudtrail[0].name
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name      = "RootUsage"
    namespace = "IAMSecurity"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_usage" {
  count               = var.enable_iam_monitoring ? 1 : 0
  alarm_name          = "${var.project_name}-root-usage-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "RootUsage"
  namespace           = "IAMSecurity"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Root account usage detected"
  alarm_actions       = [aws_sns_topic.security_alerts[0].arn]

  tags = {
    Name        = "${var.project_name}-root-usage-alarm"
    Environment = var.environment
  }
}

# SNS Topic for Security Alerts
resource "aws_sns_topic" "security_alerts" {
  count = var.enable_iam_monitoring ? 1 : 0
  name  = "${var.project_name}-security-alerts"

  tags = {
    Name        = "${var.project_name}-security-alerts"
    Environment = var.environment
  }
}

# CloudWatch Log Group for CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail" {
  count             = var.enable_iam_cloudtrail ? 1 : 0
  name              = "/aws/cloudtrail/${var.project_name}-iam-audit"
  retention_in_days = var.cloudtrail_log_retention_days

  tags = {
    Name        = "${var.project_name}-cloudtrail-logs"
    Environment = var.environment
  }
}