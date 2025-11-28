# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-lambda-logs"
    Environment = var.environment
  }
}

# CloudWatch Alarms for Lambda
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "This metric monitors Lambda function errors"
  alarm_actions       = [aws_sns_topic.lambda_alerts.arn]

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = {
    Name        = "${var.project_name}-lambda-errors-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.project_name}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = var.duration_threshold
  alarm_description   = "This metric monitors Lambda function duration"
  alarm_actions       = [aws_sns_topic.lambda_alerts.arn]

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = {
    Name        = "${var.project_name}-lambda-duration-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.project_name}-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.throttle_threshold
  alarm_description   = "This metric monitors Lambda function throttles"
  alarm_actions       = [aws_sns_topic.lambda_alerts.arn]

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = {
    Name        = "${var.project_name}-lambda-throttles-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_concurrent_executions" {
  alarm_name          = "${var.project_name}-lambda-concurrent-executions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ConcurrentExecutions"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Maximum"
  threshold           = var.concurrent_executions_threshold
  alarm_description   = "This metric monitors Lambda concurrent executions"
  alarm_actions       = [aws_sns_topic.lambda_alerts.arn]

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = {
    Name        = "${var.project_name}-lambda-concurrent-executions-alarm"
    Environment = var.environment
  }
}

# SNS Topic for Lambda Alerts
resource "aws_sns_topic" "lambda_alerts" {
  name = "${var.project_name}-lambda-alerts"

  tags = {
    Name        = "${var.project_name}-lambda-alerts"
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "lambda_email" {
  count     = length(var.alert_email_addresses)
  topic_arn = aws_sns_topic.lambda_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email_addresses[count.index]
}

# CloudWatch Dashboard for Lambda
resource "aws_cloudwatch_dashboard" "lambda" {
  dashboard_name = "${var.project_name}-lambda-dashboard"

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
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."],
            [".", "Throttles", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Function Metrics"
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
            ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", var.lambda_function_name],
            [".", "DeadLetterErrors", ".", "."],
            [".", "DestinationDeliveryFailures", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Execution Metrics"
          period  = 300
        }
      }
    ]
  })
}

# X-Ray Tracing (if enabled)
resource "aws_lambda_function" "monitored" {
  count            = var.enable_xray_tracing ? 1 : 0
  filename         = var.lambda_filename
  function_name    = "${var.lambda_function_name}-monitored"
  role            = var.lambda_execution_role_arn
  handler         = var.lambda_handler
  source_code_hash = var.lambda_source_code_hash
  runtime         = var.lambda_runtime

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name        = "${var.lambda_function_name}-monitored"
    Environment = var.environment
  }
}

# CloudWatch Insights Queries
resource "aws_cloudwatch_query_definition" "lambda_errors" {
  name = "${var.project_name}-lambda-errors"

  log_group_names = [
    aws_cloudwatch_log_group.lambda.name
  ]

  query_string = <<EOF
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
EOF
}

resource "aws_cloudwatch_query_definition" "lambda_performance" {
  name = "${var.project_name}-lambda-performance"

  log_group_names = [
    aws_cloudwatch_log_group.lambda.name
  ]

  query_string = <<EOF
fields @timestamp, @duration, @billedDuration, @memorySize, @maxMemoryUsed
| filter @type = "REPORT"
| sort @timestamp desc
| limit 100
EOF
}

# Custom Metrics (if needed)
resource "aws_cloudwatch_log_metric_filter" "lambda_custom_metric" {
  count          = length(var.custom_metrics)
  name           = var.custom_metrics[count.index].name
  log_group_name = aws_cloudwatch_log_group.lambda.name
  pattern        = var.custom_metrics[count.index].pattern

  metric_transformation {
    name      = var.custom_metrics[count.index].metric_name
    namespace = var.custom_metrics[count.index].namespace
    value     = var.custom_metrics[count.index].value
  }
}

# Lambda Insights (Enhanced Monitoring)
resource "aws_lambda_layer_version" "lambda_insights" {
  count               = var.enable_lambda_insights ? 1 : 0
  filename            = "lambda-insights-extension.zip"
  layer_name          = "${var.project_name}-lambda-insights"
  compatible_runtimes = [var.lambda_runtime]
  description         = "Lambda Insights Extension"

  tags = {
    Name        = "${var.project_name}-lambda-insights"
    Environment = var.environment
  }
}