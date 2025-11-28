# AWS Backup Vault
resource "aws_backup_vault" "main" {
  name        = "${var.project_name}-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn

  tags = {
    Name        = "${var.project_name}-backup-vault"
    Environment = var.environment
  }
}

# KMS Key for Backup Encryption
resource "aws_kms_key" "backup" {
  description             = "KMS key for AWS Backup"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-backup-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "backup" {
  name          = "alias/${var.project_name}-backup"
  target_key_id = aws_kms_key.backup.key_id
}

# Backup Plan
resource "aws_backup_plan" "main" {
  name = "${var.project_name}-backup-plan"

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = var.backup_schedule

    lifecycle {
      cold_storage_after = var.cold_storage_after_days
      delete_after       = var.delete_after_days
    }

    recovery_point_tags = {
      Environment = var.environment
      BackupType  = "Daily"
    }
  }

  rule {
    rule_name         = "weekly_backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = var.weekly_backup_schedule

    lifecycle {
      cold_storage_after = var.weekly_cold_storage_after_days
      delete_after       = var.weekly_delete_after_days
    }

    recovery_point_tags = {
      Environment = var.environment
      BackupType  = "Weekly"
    }
  }

  advanced_backup_setting {
    backup_options = {
      WindowsVSS = "enabled"
    }
    resource_type = "EC2"
  }
}

# Backup Selection
resource "aws_backup_selection" "main" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.project_name}-backup-selection"
  plan_id      = aws_backup_plan.main.id

  resources = var.backup_resources

  dynamic "selection_tag" {
    for_each = var.backup_selection_tags
    content {
      type  = selection_tag.value.type
      key   = selection_tag.value.key
      value = selection_tag.value.value
    }
  }
}

# IAM Role for AWS Backup
resource "aws_iam_role" "backup" {
  name = "${var.project_name}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Cross-Region Backup
resource "aws_backup_region_settings" "main" {
  resource_type_opt_in_preference = {
    "Aurora"          = var.enable_aurora_backup
    "DocumentDB"      = var.enable_documentdb_backup
    "DynamoDB"        = var.enable_dynamodb_backup
    "EBS"             = var.enable_ebs_backup
    "EC2"             = var.enable_ec2_backup
    "EFS"             = var.enable_efs_backup
    "FSx"             = var.enable_fsx_backup
    "Neptune"         = var.enable_neptune_backup
    "RDS"             = var.enable_rds_backup
    "Storage Gateway" = var.enable_storage_gateway_backup
  }

  resource_type_management_preference = {
    "DynamoDB" = var.enable_dynamodb_management
    "EFS"      = var.enable_efs_management
  }
}