# EFS File System
resource "aws_efs_file_system" "main" {
  creation_token                  = var.creation_token
  performance_mode               = var.performance_mode
  throughput_mode                = var.throughput_mode
  provisioned_throughput_in_mibps = var.throughput_mode == "provisioned" ? var.provisioned_throughput_in_mibps : null
  encrypted                      = var.encrypted
  kms_key_id                     = var.kms_key_id

  dynamic "lifecycle_policy" {
    for_each = var.lifecycle_policy != null ? [var.lifecycle_policy] : []
    content {
      transition_to_ia                    = lifecycle_policy.value.transition_to_ia
      transition_to_primary_storage_class = lifecycle_policy.value.transition_to_primary_storage_class
    }
  }

  tags = {
    Name        = "${var.project_name}-efs"
    Environment = var.environment
  }
}

# EFS Mount Targets
resource "aws_efs_mount_target" "main" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

# Security Group for EFS
resource "aws_security_group" "efs" {
  name_prefix = "${var.project_name}-efs-"
  vpc_id      = var.vpc_id
  description = "Security group for EFS mount targets"

  ingress {
    description     = "NFS"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = var.client_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-efs-sg"
    Environment = var.environment
  }
}

# EFS Access Point
resource "aws_efs_access_point" "main" {
  count          = length(var.access_points)
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = var.access_points[count.index].posix_user.gid
    uid = var.access_points[count.index].posix_user.uid
  }

  root_directory {
    path = var.access_points[count.index].root_directory.path
    creation_info {
      owner_gid   = var.access_points[count.index].root_directory.creation_info.owner_gid
      owner_uid   = var.access_points[count.index].root_directory.creation_info.owner_uid
      permissions = var.access_points[count.index].root_directory.creation_info.permissions
    }
  }

  tags = {
    Name        = "${var.project_name}-efs-ap-${count.index + 1}"
    Environment = var.environment
  }
}

# EFS Backup Policy
resource "aws_efs_backup_policy" "main" {
  count          = var.enable_backup_policy ? 1 : 0
  file_system_id = aws_efs_file_system.main.id

  backup_policy {
    status = "ENABLED"
  }
}