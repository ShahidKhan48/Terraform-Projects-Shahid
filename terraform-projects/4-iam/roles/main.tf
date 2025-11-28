# EC2 Instance Role
resource "aws_iam_role" "ec2_instance" {
  count = var.create_ec2_instance_role ? 1 : 0
  name  = "${var.project_name}-ec2-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ec2-instance-role"
    Environment = var.environment
  }
}

# Lambda Execution Role
resource "aws_iam_role" "lambda_execution" {
  count = var.create_lambda_execution_role ? 1 : 0
  name  = "${var.project_name}-lambda-execution-role"

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

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  count = var.create_ecs_task_execution_role ? 1 : 0
  name  = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ecs-task-execution-role"
    Environment = var.environment
  }
}

# ECS Task Role
resource "aws_iam_role" "ecs_task" {
  count = var.create_ecs_task_role ? 1 : 0
  name  = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ecs-task-role"
    Environment = var.environment
  }
}

# CodeBuild Service Role
resource "aws_iam_role" "codebuild" {
  count = var.create_codebuild_role ? 1 : 0
  name  = "${var.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-codebuild-role"
    Environment = var.environment
  }
}

# CodePipeline Service Role
resource "aws_iam_role" "codepipeline" {
  count = var.create_codepipeline_role ? 1 : 0
  name  = "${var.project_name}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-codepipeline-role"
    Environment = var.environment
  }
}

# Custom Roles
resource "aws_iam_role" "custom" {
  count              = length(var.custom_roles)
  name               = var.custom_roles[count.index].name
  assume_role_policy = var.custom_roles[count.index].assume_role_policy
  description        = var.custom_roles[count.index].description
  max_session_duration = var.custom_roles[count.index].max_session_duration

  tags = {
    Name        = var.custom_roles[count.index].name
    Environment = var.environment
  }
}