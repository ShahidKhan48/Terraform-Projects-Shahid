# CloudWatch Container Insights
resource "aws_eks_addon" "cloudwatch_observability" {
  count         = var.enable_container_insights ? 1 : 0
  cluster_name  = var.cluster_name
  addon_name    = "amazon-cloudwatch-observability"
  addon_version = var.cloudwatch_observability_version

  configuration_values = jsonencode({
    agent = {
      config = {
        logs = {
          metrics_collected = {
            kubernetes = {
              enhanced_container_insights = var.enable_enhanced_container_insights
            }
          }
        }
      }
    }
  })

  tags = {
    Name        = "${var.cluster_name}-cloudwatch-observability"
    Environment = var.environment
  }
}

# CloudWatch Log Groups for EKS
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.cluster_name}-cluster-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "eks_application" {
  name              = "/aws/containerinsights/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.cluster_name}-application-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "eks_dataplane" {
  name              = "/aws/containerinsights/${var.cluster_name}/dataplane"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.cluster_name}-dataplane-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "eks_host" {
  name              = "/aws/containerinsights/${var.cluster_name}/host"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.cluster_name}-host-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "eks_performance" {
  name              = "/aws/containerinsights/${var.cluster_name}/performance"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.cluster_name}-performance-logs"
    Environment = var.environment
  }
}

# CloudWatch Alarms for EKS Cluster
resource "aws_cloudwatch_metric_alarm" "cluster_failed_request_count" {
  alarm_name          = "${var.cluster_name}-cluster-failed-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "cluster_failed_request_count"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.failed_request_threshold
  alarm_description   = "EKS cluster failed request count"
  alarm_actions       = [aws_sns_topic.eks_alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = {
    Name        = "${var.cluster_name}-failed-requests-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "node_cpu_utilization" {
  alarm_name          = "${var.cluster_name}-node-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = var.node_cpu_threshold
  alarm_description   = "EKS node high CPU utilization"
  alarm_actions       = [aws_sns_topic.eks_alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = {
    Name        = "${var.cluster_name}-node-cpu-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "node_memory_utilization" {
  alarm_name          = "${var.cluster_name}-node-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = var.node_memory_threshold
  alarm_description   = "EKS node high memory utilization"
  alarm_actions       = [aws_sns_topic.eks_alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = {
    Name        = "${var.cluster_name}-node-memory-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "pod_cpu_utilization" {
  alarm_name          = "${var.cluster_name}-pod-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "pod_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = var.pod_cpu_threshold
  alarm_description   = "EKS pod high CPU utilization"
  alarm_actions       = [aws_sns_topic.eks_alerts.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = {
    Name        = "${var.cluster_name}-pod-cpu-alarm"
    Environment = var.environment
  }
}

# SNS Topic for EKS Alerts
resource "aws_sns_topic" "eks_alerts" {
  name = "${var.cluster_name}-alerts"

  tags = {
    Name        = "${var.cluster_name}-alerts"
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "eks_email" {
  count     = length(var.alert_email_addresses)
  topic_arn = aws_sns_topic.eks_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email_addresses[count.index]
}

# CloudWatch Dashboard for EKS
resource "aws_cloudwatch_dashboard" "eks" {
  dashboard_name = "${var.cluster_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["ContainerInsights", "cluster_node_count", "ClusterName", var.cluster_name],
            [".", "cluster_failed_request_count", ".", "."],
            [".", "namespace_number_of_running_pods", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "EKS Cluster Overview"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["ContainerInsights", "node_cpu_utilization", "ClusterName", var.cluster_name],
            [".", "node_memory_utilization", ".", "."],
            [".", "node_network_total_bytes", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Node Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["ContainerInsights", "pod_cpu_utilization", "ClusterName", var.cluster_name],
            [".", "pod_memory_utilization", ".", "."],
            [".", "pod_network_rx_bytes", ".", "."],
            [".", "pod_network_tx_bytes", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Pod Metrics"
          period  = 300
        }
      }
    ]
  })
}

# Prometheus and Grafana (Optional)
resource "helm_release" "prometheus" {
  count      = var.enable_prometheus ? 1 : 0
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = var.prometheus_version

  create_namespace = true

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          retention                               = var.prometheus_retention
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.prometheus_storage_class
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
              }
            }
          }
        }
      }
      grafana = {
        adminPassword = var.grafana_admin_password
        persistence = {
          enabled          = true
          storageClassName = var.grafana_storage_class
          size             = var.grafana_storage_size
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

resource "kubernetes_namespace" "monitoring" {
  count = var.enable_prometheus ? 1 : 0
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }
}