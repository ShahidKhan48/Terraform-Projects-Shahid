# EBS Volume
resource "aws_ebs_volume" "main" {
  count             = var.volume_count
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  size              = var.volume_size
  type              = var.volume_type
  iops              = var.volume_type == "gp3" || var.volume_type == "io1" || var.volume_type == "io2" ? var.iops : null
  throughput        = var.volume_type == "gp3" ? var.throughput : null
  encrypted         = var.encrypted
  kms_key_id        = var.kms_key_id

  tags = {
    Name        = "${var.project_name}-ebs-${count.index + 1}"
    Environment = var.environment
  }
}

# EBS Volume Attachment
resource "aws_volume_attachment" "main" {
  count       = var.attach_to_instance ? var.volume_count : 0
  device_name = var.device_names[count.index % length(var.device_names)]
  volume_id   = aws_ebs_volume.main[count.index].id
  instance_id = var.instance_ids[count.index % length(var.instance_ids)]
}

# EBS Snapshot
resource "aws_ebs_snapshot" "main" {
  count       = var.create_snapshots ? var.volume_count : 0
  volume_id   = aws_ebs_volume.main[count.index].id
  description = "Snapshot of ${var.project_name}-ebs-${count.index + 1}"

  tags = {
    Name        = "${var.project_name}-snapshot-${count.index + 1}"
    Environment = var.environment
  }
}

# EBS Snapshot Copy (for cross-region backup)
resource "aws_ebs_snapshot_copy" "cross_region" {
  count              = var.cross_region_backup ? var.volume_count : 0
  source_snapshot_id = aws_ebs_snapshot.main[count.index].id
  source_region      = var.source_region
  description        = "Cross-region copy of ${var.project_name}-snapshot-${count.index + 1}"
  encrypted          = var.encrypted

  tags = {
    Name        = "${var.project_name}-snapshot-copy-${count.index + 1}"
    Environment = var.environment
  }
}