# S3 Bucket Notification for Lambda
resource "aws_s3_bucket_notification" "lambda_trigger" {
  count  = length(var.s3_triggers)
  bucket = var.s3_triggers[count.index].bucket_name

  lambda_function {
    lambda_function_arn = var.s3_triggers[count.index].lambda_function_arn
    events              = var.s3_triggers[count.index].events
    filter_prefix       = var.s3_triggers[count.index].filter_prefix
    filter_suffix       = var.s3_triggers[count.index].filter_suffix
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

# Lambda Permission for S3
resource "aws_lambda_permission" "s3_invoke" {
  count         = length(var.s3_triggers)
  statement_id  = "AllowExecutionFromS3Bucket-${count.index}"
  action        = "lambda:InvokeFunction"
  function_name = var.s3_triggers[count.index].lambda_function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.s3_triggers[count.index].bucket_name}"
}

# CloudWatch Event Rule
resource "aws_cloudwatch_event_rule" "lambda_trigger" {
  count               = length(var.cloudwatch_triggers)
  name                = var.cloudwatch_triggers[count.index].rule_name
  description         = var.cloudwatch_triggers[count.index].description
  schedule_expression = var.cloudwatch_triggers[count.index].schedule_expression
  event_pattern       = var.cloudwatch_triggers[count.index].event_pattern

  tags = {
    Name        = var.cloudwatch_triggers[count.index].rule_name
    Environment = var.environment
  }
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "lambda" {
  count     = length(var.cloudwatch_triggers)
  rule      = aws_cloudwatch_event_rule.lambda_trigger[count.index].name
  target_id = "TargetId${count.index}"
  arn       = var.cloudwatch_triggers[count.index].lambda_function_arn

  dynamic "input_transformer" {
    for_each = var.cloudwatch_triggers[count.index].input_transformer != null ? [var.cloudwatch_triggers[count.index].input_transformer] : []
    content {
      input_paths    = input_transformer.value.input_paths
      input_template = input_transformer.value.input_template
    }
  }
}

# Lambda Permission for CloudWatch Events
resource "aws_lambda_permission" "cloudwatch_invoke" {
  count         = length(var.cloudwatch_triggers)
  statement_id  = "AllowExecutionFromCloudWatch-${count.index}"
  action        = "lambda:InvokeFunction"
  function_name = var.cloudwatch_triggers[count.index].lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_trigger[count.index].arn
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "lambda" {
  count     = length(var.sns_triggers)
  topic_arn = var.sns_triggers[count.index].topic_arn
  protocol  = "lambda"
  endpoint  = var.sns_triggers[count.index].lambda_function_arn
}

# Lambda Permission for SNS
resource "aws_lambda_permission" "sns_invoke" {
  count         = length(var.sns_triggers)
  statement_id  = "AllowExecutionFromSNS-${count.index}"
  action        = "lambda:InvokeFunction"
  function_name = var.sns_triggers[count.index].lambda_function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_triggers[count.index].topic_arn
}

# SQS Event Source Mapping
resource "aws_lambda_event_source_mapping" "sqs" {
  count            = length(var.sqs_triggers)
  event_source_arn = var.sqs_triggers[count.index].queue_arn
  function_name    = var.sqs_triggers[count.index].lambda_function_arn
  batch_size       = var.sqs_triggers[count.index].batch_size
  maximum_batching_window_in_seconds = var.sqs_triggers[count.index].maximum_batching_window_in_seconds

  dynamic "filter_criteria" {
    for_each = var.sqs_triggers[count.index].filter_criteria != null ? [var.sqs_triggers[count.index].filter_criteria] : []
    content {
      dynamic "filter" {
        for_each = filter_criteria.value.filters
        content {
          pattern = filter.value.pattern
        }
      }
    }
  }
}

# DynamoDB Event Source Mapping
resource "aws_lambda_event_source_mapping" "dynamodb" {
  count                  = length(var.dynamodb_triggers)
  event_source_arn       = var.dynamodb_triggers[count.index].stream_arn
  function_name          = var.dynamodb_triggers[count.index].lambda_function_arn
  starting_position      = var.dynamodb_triggers[count.index].starting_position
  batch_size             = var.dynamodb_triggers[count.index].batch_size
  maximum_batching_window_in_seconds = var.dynamodb_triggers[count.index].maximum_batching_window_in_seconds
  parallelization_factor = var.dynamodb_triggers[count.index].parallelization_factor

  dynamic "destination_config" {
    for_each = var.dynamodb_triggers[count.index].destination_config != null ? [var.dynamodb_triggers[count.index].destination_config] : []
    content {
      dynamic "on_failure" {
        for_each = destination_config.value.on_failure != null ? [destination_config.value.on_failure] : []
        content {
          destination_arn = on_failure.value.destination_arn
        }
      }
    }
  }
}