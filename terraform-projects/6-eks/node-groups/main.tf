# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-${var.node_group_name}"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  # Scaling Configuration
  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  # Update Configuration
  update_config {
    max_unavailable_percentage = var.max_unavailable_percentage
  }

  # Instance Configuration
  instance_types = var.instance_types
  capacity_type  = var.capacity_type
  disk_size      = var.disk_size
  ami_type       = var.ami_type

  # Remote Access
  dynamic "remote_access" {
    for_each = var.enable_remote_access ? [1] : []
    content {
      ec2_ssh_key               = var.ec2_ssh_key
      source_security_group_ids = var.source_security_group_ids
    }
  }

  # Launch Template
  dynamic "launch_template" {
    for_each = var.launch_template_id != null ? [1] : []
    content {
      id      = var.launch_template_id
      version = var.launch_template_version
    }
  }

  # Taints
  dynamic "taint" {
    for_each = var.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  # Labels
  labels = var.labels

  tags = merge(
    {
      Name        = "${var.cluster_name}-${var.node_group_name}"
      Environment = var.environment
    },
    var.additional_tags
  )

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  depends_on = [
    var.node_role_policy_attachments
  ]
}

# Launch Template for Custom Configuration
resource "aws_launch_template" "node_group" {
  count       = var.create_launch_template ? 1 : 0
  name_prefix = "${var.cluster_name}-${var.node_group_name}-"

  # Instance Configuration
  image_id      = var.custom_ami_id
  instance_type = var.instance_types[0]
  key_name      = var.ec2_ssh_key

  # VPC Security Group
  vpc_security_group_ids = var.security_group_ids

  # User Data
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cluster_name        = var.cluster_name
    cluster_endpoint    = var.cluster_endpoint
    cluster_ca          = var.cluster_ca_data
    bootstrap_arguments = var.bootstrap_arguments
  }))

  # Block Device Mapping
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.disk_size
      volume_type           = var.volume_type
      encrypted             = var.enable_ebs_encryption
      kms_key_id           = var.kms_key_id
      delete_on_termination = true
    }
  }

  # Instance Metadata Options
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  # Monitoring
  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  # Network Interface
  network_interfaces {
    associate_public_ip_address = var.associate_public_ip_address
    delete_on_termination       = true
    security_groups            = var.security_group_ids
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      {
        Name        = "${var.cluster_name}-${var.node_group_name}"
        Environment = var.environment
      },
      var.additional_tags
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      {
        Name        = "${var.cluster_name}-${var.node_group_name}-volume"
        Environment = var.environment
      },
      var.additional_tags
    )
  }

  tags = {
    Name        = "${var.cluster_name}-${var.node_group_name}-lt"
    Environment = var.environment
  }
}

# Managed Node Group with Spot Instances
resource "aws_eks_node_group" "spot" {
  count           = var.create_spot_node_group ? 1 : 0
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-${var.node_group_name}-spot"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.spot_desired_size
    max_size     = var.spot_max_size
    min_size     = var.spot_min_size
  }

  update_config {
    max_unavailable_percentage = var.max_unavailable_percentage
  }

  instance_types = var.spot_instance_types
  capacity_type  = "SPOT"
  disk_size      = var.disk_size
  ami_type       = var.ami_type

  # Taints for spot instances
  taint {
    key    = "spot"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  labels = merge(
    var.labels,
    {
      "node-type" = "spot"
    }
  )

  tags = merge(
    {
      Name        = "${var.cluster_name}-${var.node_group_name}-spot"
      Environment = var.environment
      NodeType    = "spot"
    },
    var.additional_tags
  )

  depends_on = [
    var.node_role_policy_attachments
  ]
}

# Auto Scaling Group Tags for Cluster Autoscaler
resource "aws_autoscaling_group_tag" "cluster_autoscaler" {
  for_each = var.enable_cluster_autoscaler ? toset([
    "k8s.io/cluster-autoscaler/enabled",
    "k8s.io/cluster-autoscaler/${var.cluster_name}"
  ]) : toset([])

  autoscaling_group_name = aws_eks_node_group.main.resources[0].autoscaling_groups[0].name

  tag {
    key                 = each.value
    value               = each.value == "k8s.io/cluster-autoscaler/enabled" ? "true" : "owned"
    propagate_at_launch = false
  }
}

# CloudWatch Log Group for Node Group
resource "aws_cloudwatch_log_group" "node_group" {
  count             = var.enable_node_group_logging ? 1 : 0
  name              = "/aws/eks/${var.cluster_name}/node-group/${var.node_group_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.cluster_name}-${var.node_group_name}-logs"
    Environment = var.environment
  }
}