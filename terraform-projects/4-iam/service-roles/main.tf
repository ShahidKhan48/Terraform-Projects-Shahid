# EKS Cluster Service Role
resource "aws_iam_role" "eks_cluster" {
  count = var.create_eks_cluster_role ? 1 : 0
  name  = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-eks-cluster-role"
    Environment = var.environment
  }
}

# EKS Node Group Role
resource "aws_iam_role" "eks_node_group" {
  count = var.create_eks_node_group_role ? 1 : 0
  name  = "${var.project_name}-eks-node-group-role"

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
    Name        = "${var.project_name}-eks-node-group-role"
    Environment = var.environment
  }
}

# RDS Enhanced Monitoring Role
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.create_rds_enhanced_monitoring_role ? 1 : 0
  name  = "${var.project_name}-rds-enhanced-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-rds-enhanced-monitoring-role"
    Environment = var.environment
  }
}

# Auto Scaling Service Role
resource "aws_iam_role" "autoscaling" {
  count = var.create_autoscaling_role ? 1 : 0
  name  = "${var.project_name}-autoscaling-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "autoscaling.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-autoscaling-role"
    Environment = var.environment
  }
}

# CloudFormation Service Role
resource "aws_iam_role" "cloudformation" {
  count = var.create_cloudformation_role ? 1 : 0
  name  = "${var.project_name}-cloudformation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudformation.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-cloudformation-role"
    Environment = var.environment
  }
}

# API Gateway CloudWatch Role
resource "aws_iam_role" "api_gateway_cloudwatch" {
  count = var.create_api_gateway_cloudwatch_role ? 1 : 0
  name  = "${var.project_name}-api-gateway-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-api-gateway-cloudwatch-role"
    Environment = var.environment
  }
}

# Attach AWS Managed Policies to EKS Cluster Role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.create_eks_cluster_role ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster[0].name
}

# Attach AWS Managed Policies to EKS Node Group Role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  count      = var.create_eks_node_group_role ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  count      = var.create_eks_node_group_role ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group[0].name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_readonly" {
  count      = var.create_eks_node_group_role ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group[0].name
}

# Attach AWS Managed Policy to RDS Enhanced Monitoring Role
resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count      = var.create_rds_enhanced_monitoring_role ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = aws_iam_role.rds_enhanced_monitoring[0].name
}

# Attach AWS Managed Policy to Auto Scaling Role
resource "aws_iam_role_policy_attachment" "autoscaling_notification" {
  count      = var.create_autoscaling_role ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"
  role       = aws_iam_role.autoscaling[0].name
}