# RDS Automated Backup Configuration
resource "aws_db_instance" "main" {
  identifier = var.db_instance_identifier
  
  # Backup Configuration
  backup_retention_period   = var.backup_retention_period
  backup_window            = var.backup_window
  maintenance_window       = var.maintenance_window
  delete_automated_backups = var.delete_automated_backups
  
  # Point-in-time Recovery
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  
  # Snapshot Configuration
  final_snapshot_identifier = "${var.db_instance_identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  skip_final_snapshot      = var.skip_final_snapshot
  
  tags = {
    Name        = var.db_instance_identifier
    Environment = var.environment
    BackupEnabled = "true"
  }
}

# Manual DB Snapshot
resource "aws_db_snapshot" "manual" {
  count                  = var.create_manual_snapshot ? 1 : 0
  db_instance_identifier = aws_db_instance.main.id
  db_snapshot_identifier = "${var.db_instance_identifier}-manual-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = {
    Name        = "${var.db_instance_identifier}-manual-snapshot"
    Environment = var.environment
    Type        = "Manual"
  }
}

# Cross-Region Snapshot Copy
resource "aws_db_snapshot_copy" "cross_region" {
  count                          = var.enable_cross_region_backup ? 1 : 0
  source_db_snapshot_identifier = aws_db_snapshot.manual[0].db_snapshot_arn
  target_db_snapshot_identifier = "${var.db_instance_identifier}-cross-region-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  # KMS encryption for cross-region copy
  kms_key_id = var.cross_region_kms_key_id

  tags = {
    Name        = "${var.db_instance_identifier}-cross-region-backup"
    Environment = var.environment
    Type        = "CrossRegion"
  }
}

# DynamoDB Backup Configuration
resource "aws_dynamodb_table" "main" {
  count = var.create_dynamodb_table ? 1 : 0
  name  = var.dynamodb_table_name
  
  # Point-in-time Recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
  
  tags = {
    Name        = var.dynamodb_table_name
    Environment = var.environment
    BackupEnabled = "true"
  }
}

# DynamoDB Backup Vault
resource "aws_backup_selection" "dynamodb" {
  count        = var.enable_dynamodb_backup ? 1 : 0
  iam_role_arn = aws_iam_role.backup[0].arn
  name         = "${var.project_name}-dynamodb-backup"
  plan_id      = aws_backup_plan.database[0].id

  resources = [
    aws_dynamodb_table.main[0].arn
  ]
}

# Backup Plan for Databases
resource "aws_backup_plan" "database" {
  count = var.enable_aws_backup ? 1 : 0
  name  = "${var.project_name}-database-backup-plan"

  rule {
    rule_name         = "daily_database_backup"
    target_vault_name = aws_backup_vault.database[0].name
    schedule          = var.backup_schedule

    lifecycle {
      cold_storage_after = var.cold_storage_after_days
      delete_after       = var.delete_after_days
    }

    recovery_point_tags = {
      Environment = var.environment
      BackupType  = "Database"
    }
  }

  rule {
    rule_name         = "weekly_database_backup"
    target_vault_name = aws_backup_vault.database[0].name
    schedule          = var.weekly_backup_schedule

    lifecycle {
      cold_storage_after = var.weekly_cold_storage_after_days
      delete_after       = var.weekly_delete_after_days
    }

    recovery_point_tags = {
      Environment = var.environment
      BackupType  = "WeeklyDatabase"
    }
  }
}

# Backup Vault for Databases
resource "aws_backup_vault" "database" {
  count       = var.enable_aws_backup ? 1 : 0
  name        = "${var.project_name}-database-backup-vault"
  kms_key_arn = aws_kms_key.backup[0].arn

  tags = {
    Name        = "${var.project_name}-database-backup-vault"
    Environment = var.environment
  }
}

# KMS Key for Database Backup
resource "aws_kms_key" "backup" {
  count                   = var.enable_aws_backup ? 1 : 0
  description             = "KMS key for database backup encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-database-backup-key"
    Environment = var.environment
  }
}

# IAM Role for Database Backup
resource "aws_iam_role" "backup" {
  count = var.enable_aws_backup ? 1 : 0
  name  = "${var.project_name}-database-backup-role"

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

resource "aws_iam_role_policy_attachment" "backup_policy" {
  count      = var.enable_aws_backup ? 1 : 0
  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore_policy" {
  count      = var.enable_aws_backup ? 1 : 0
  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}