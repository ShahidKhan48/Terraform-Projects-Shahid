# FSx for Windows File Server
resource "aws_fsx_windows_file_system" "main" {
  count                         = var.file_system_type == "windows" ? 1 : 0
  active_directory_id           = var.active_directory_id
  automatic_backup_retention_days = var.automatic_backup_retention_days
  copy_tags_to_backups          = var.copy_tags_to_backups
  daily_automatic_backup_start_time = var.daily_automatic_backup_start_time
  deployment_type               = var.deployment_type
  kms_key_id                   = var.kms_key_id
  security_group_ids           = var.security_group_ids
  skip_final_backup            = var.skip_final_backup
  storage_capacity             = var.storage_capacity
  storage_type                 = var.storage_type
  subnet_ids                   = var.subnet_ids
  throughput_capacity          = var.throughput_capacity
  weekly_maintenance_start_time = var.weekly_maintenance_start_time

  tags = {
    Name        = "${var.project_name}-fsx-windows"
    Environment = var.environment
  }
}

# FSx for Lustre File System
resource "aws_fsx_lustre_file_system" "main" {
  count                         = var.file_system_type == "lustre" ? 1 : 0
  storage_capacity              = var.storage_capacity
  subnet_ids                    = var.subnet_ids
  deployment_type               = var.deployment_type
  storage_type                  = var.storage_type
  per_unit_storage_throughput   = var.per_unit_storage_throughput
  automatic_backup_retention_days = var.automatic_backup_retention_days
  copy_tags_to_backups          = var.copy_tags_to_backups
  daily_automatic_backup_start_time = var.daily_automatic_backup_start_time
  data_compression_type         = var.data_compression_type
  export_path                   = var.export_path
  import_path                   = var.import_path
  imported_file_chunk_size      = var.imported_file_chunk_size
  security_group_ids            = var.security_group_ids
  weekly_maintenance_start_time = var.weekly_maintenance_start_time

  tags = {
    Name        = "${var.project_name}-fsx-lustre"
    Environment = var.environment
  }
}

# FSx for NetApp ONTAP File System
resource "aws_fsx_ontap_file_system" "main" {
  count                         = var.file_system_type == "ontap" ? 1 : 0
  deployment_type               = var.deployment_type
  storage_capacity              = var.storage_capacity
  subnet_ids                    = var.subnet_ids
  throughput_capacity           = var.throughput_capacity
  automatic_backup_retention_days = var.automatic_backup_retention_days
  daily_automatic_backup_start_time = var.daily_automatic_backup_start_time
  disk_iops_configuration {
    mode = var.disk_iops_mode
    iops = var.disk_iops_mode == "USER_PROVISIONED" ? var.disk_iops : null
  }
  endpoint_ip_address_range     = var.endpoint_ip_address_range
  fsx_admin_password           = var.fsx_admin_password
  kms_key_id                   = var.kms_key_id
  preferred_subnet_id          = var.preferred_subnet_id
  route_table_ids              = var.route_table_ids
  security_group_ids           = var.security_group_ids
  weekly_maintenance_start_time = var.weekly_maintenance_start_time

  tags = {
    Name        = "${var.project_name}-fsx-ontap"
    Environment = var.environment
  }
}

# FSx for OpenZFS File System
resource "aws_fsx_openzfs_file_system" "main" {
  count                         = var.file_system_type == "openzfs" ? 1 : 0
  deployment_type               = var.deployment_type
  storage_capacity              = var.storage_capacity
  subnet_ids                    = var.subnet_ids
  throughput_capacity           = var.throughput_capacity
  automatic_backup_retention_days = var.automatic_backup_retention_days
  copy_tags_to_backups          = var.copy_tags_to_backups
  copy_tags_to_volumes          = var.copy_tags_to_volumes
  daily_automatic_backup_start_time = var.daily_automatic_backup_start_time
  kms_key_id                   = var.kms_key_id
  security_group_ids           = var.security_group_ids
  storage_type                 = var.storage_type
  weekly_maintenance_start_time = var.weekly_maintenance_start_time

  disk_iops_configuration {
    mode = var.disk_iops_mode
    iops = var.disk_iops_mode == "USER_PROVISIONED" ? var.disk_iops : null
  }

  root_volume_configuration {
    data_compression_type = var.data_compression_type
    nfs_exports {
      client_configurations {
        clients = var.nfs_client_configurations.clients
        options = var.nfs_client_configurations.options
      }
    }
    user_and_group_quotas {
      id                         = var.user_and_group_quotas.id
      storage_capacity_quota_gib = var.user_and_group_quotas.storage_capacity_quota_gib
      type                       = var.user_and_group_quotas.type
    }
  }

  tags = {
    Name        = "${var.project_name}-fsx-openzfs"
    Environment = var.environment
  }
}