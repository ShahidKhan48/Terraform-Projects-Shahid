# CloudWatch Log Group for Database
resource "aws_cloudwatch_log_group" "database" {
  name              = "/aws/rds/instance/${var.db_instance_identifier}/error"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-db-logs"
    Environment = var.environment
  }
}

# CloudWatch Alarms for RDS
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.project_name}-db-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.database_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.db_instance_identifier
  }

  tags = {
    Name        = "${var.project_name}-db-cpu-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "database_connections" {
  alarm_name          = "${var.project_name}-db-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.connection_threshold
  alarm_description   = "This metric monitors RDS connection count"
  alarm_actions       = [aws_sns_topic.database_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.db_instance_identifier
  }

  tags = {
    Name        = "${var.project_name}-db-connections-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "database_free_storage" {
  alarm_name          = "${var.project_name}-db-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.free_storage_threshold
  alarm_description   = "This metric monitors RDS free storage space"
  alarm_actions       = [aws_sns_topic.database_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.db_instance_identifier
  }

  tags = {
    Name        = "${var.project_name}-db-storage-alarm"
    Environment = var.environment
  }
}

# SNS Topic for Database Alerts
resource "aws_sns_topic" "database_alerts" {
  name = "${var.project_name}-database-alerts"

  tags = {
    Name        = "${var.project_name}-database-alerts"
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "database_email" {
  count     = length(var.alert_email_addresses)
  topic_arn = aws_sns_topic.database_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email_addresses[count.index]
}

# CloudWatch Dashboard for Database
resource "aws_cloudwatch_dashboard" "database" {
  dashboard_name = "${var.project_name}-database-dashboard"

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
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_identifier],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeStorageSpace", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "RDS Metrics"
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
            ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", var.db_instance_identifier],
            [".", "WriteLatency", ".", "."],
            [".", "ReadIOPS", ".", "."],
            [".", "WriteIOPS", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "RDS Performance"
          period  = 300
        }
      }
    ]
  })
}

# Performance Insights (if enabled)
resource "aws_db_parameter_group" "monitoring" {
  count  = var.enable_performance_insights ? 1 : 0
  family = var.db_parameter_group_family
  name   = "${var.project_name}-monitoring-params"

  parameter {
    name  = "performance_insights_retention_period"
    value = var.performance_insights_retention_period
  }

  tags = {
    Name        = "${var.project_name}-monitoring-params"
    Environment = var.environment
  }
}