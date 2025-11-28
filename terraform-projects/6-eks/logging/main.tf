# EKS Cluster Logging Configuration
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_service_role_arn

  # Enable logging for all log types
  enabled_cluster_log_types = var.enabled_cluster_log_types

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
  }

  depends_on = [
    aws_cloudwatch_log_group.eks_cluster
  ]
}

# CloudWatch Log Groups for different EKS log types
resource "aws_cloudwatch_log_group" "eks_cluster" {
  for_each          = toset(var.enabled_cluster_log_types)
  name              = "/aws/eks/${var.cluster_name}/${each.value}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.cluster_name}-${each.value}-logs"
    Environment = var.environment
  }
}

# Fluent Bit for Application Logging
resource "helm_release" "fluent_bit" {
  count      = var.enable_fluent_bit ? 1 : 0
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  namespace  = "amazon-cloudwatch"
  version    = var.fluent_bit_version

  create_namespace = true

  values = [
    yamlencode({
      serviceAccount = {
        create = true
        name   = "fluent-bit"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.fluent_bit[0].arn
        }
      }
      config = {
        service = {
          Flush         = 5
          Log_Level     = var.fluent_bit_log_level
          Daemon        = "off"
          Parsers_File  = "parsers.conf"
          HTTP_Server   = "On"
          HTTP_Listen   = "0.0.0.0"
          HTTP_Port     = 2020
        }
        inputs = {
          tail = {
            Name              = "tail"
            Path              = "/var/log/containers/*.log"
            Parser            = "docker"
            Tag               = "kube.*"
            Refresh_Interval  = 5
            Mem_Buf_Limit     = "50MB"
            Skip_Long_Lines   = "On"
            Skip_Empty_Lines  = "On"
          }
        }
        filters = {
          kubernetes = {
            Name                = "kubernetes"
            Match               = "kube.*"
            Kube_URL            = "https://kubernetes.default.svc:443"
            Kube_CA_File        = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
            Kube_Token_File     = "/var/run/secrets/kubernetes.io/serviceaccount/token"
            Kube_Tag_Prefix     = "kube.var.log.containers."
            Merge_Log           = "On"
            Merge_Log_Key       = "log_processed"
            K8S-Logging.Parser  = "On"
            K8S-Logging.Exclude = "Off"
          }
        }
        outputs = {
          cloudwatch = {
            Name            = "cloudwatch_logs"
            Match           = "kube.*"
            region          = var.aws_region
            log_group_name  = "/aws/containerinsights/${var.cluster_name}/application"
            log_stream_name = "$kubernetes['pod_name']"
            auto_create_group = "true"
          }
        }
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.fluent_bit,
    kubernetes_namespace.amazon_cloudwatch
  ]
}

# IAM Role for Fluent Bit
resource "aws_iam_role" "fluent_bit" {
  count = var.enable_fluent_bit ? 1 : 0
  name  = "${var.cluster_name}-fluent-bit-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${var.oidc_provider}:sub" = "system:serviceaccount:amazon-cloudwatch:fluent-bit"
            "${var.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-fluent-bit-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "fluent_bit" {
  count = var.enable_fluent_bit ? 1 : 0
  name  = "${var.cluster_name}-fluent-bit-policy"
  role  = aws_iam_role.fluent_bit[0].id

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
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fluent_bit" {
  count      = var.enable_fluent_bit ? 1 : 0
  policy_arn = aws_iam_policy.fluent_bit[0].arn
  role       = aws_iam_role.fluent_bit[0].name
}

# Namespace for CloudWatch components
resource "kubernetes_namespace" "amazon_cloudwatch" {
  count = var.enable_fluent_bit ? 1 : 0
  metadata {
    name = "amazon-cloudwatch"
    labels = {
      name = "amazon-cloudwatch"
    }
  }
}

# AWS for Fluent Bit (Alternative to Fluent Bit)
resource "helm_release" "aws_for_fluent_bit" {
  count      = var.enable_aws_for_fluent_bit ? 1 : 0
  name       = "aws-for-fluent-bit"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  namespace  = "amazon-cloudwatch"
  version    = var.aws_for_fluent_bit_version

  create_namespace = true

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-for-fluent-bit"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_for_fluent_bit[0].arn
  }

  set {
    name  = "cloudWatchLogs.region"
    value = var.aws_region
  }

  set {
    name  = "cloudWatchLogs.logGroupName"
    value = "/aws/containerinsights/${var.cluster_name}/application"
  }

  set {
    name  = "firehose.enabled"
    value = var.enable_firehose_logging
  }

  set {
    name  = "kinesis.enabled"
    value = var.enable_kinesis_logging
  }

  depends_on = [
    aws_iam_role_policy_attachment.aws_for_fluent_bit
  ]
}

# IAM Role for AWS for Fluent Bit
resource "aws_iam_role" "aws_for_fluent_bit" {
  count = var.enable_aws_for_fluent_bit ? 1 : 0
  name  = "${var.cluster_name}-aws-for-fluent-bit-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${var.oidc_provider}:sub" = "system:serviceaccount:amazon-cloudwatch:aws-for-fluent-bit"
            "${var.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-aws-for-fluent-bit-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "aws_for_fluent_bit" {
  count      = var.enable_aws_for_fluent_bit ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.aws_for_fluent_bit[0].name
}

# Log Metric Filters for alerting
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  count          = var.enable_log_metric_filters ? 1 : 0
  name           = "${var.cluster_name}-error-count"
  log_group_name = "/aws/containerinsights/${var.cluster_name}/application"
  pattern        = "[timestamp, request_id, level=\"ERROR\", ...]"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "EKS/Application"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "application_errors" {
  count               = var.enable_log_metric_filters ? 1 : 0
  alarm_name          = "${var.cluster_name}-application-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ErrorCount"
  namespace           = "EKS/Application"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "Application error count exceeded threshold"
  alarm_actions       = var.alarm_actions

  tags = {
    Name        = "${var.cluster_name}-application-errors"
    Environment = var.environment
  }
}

data "aws_caller_identity" "current" {}