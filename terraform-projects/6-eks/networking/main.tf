# EKS Cluster Networking Configuration
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_service_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = var.additional_security_group_ids
  }

  # Network configuration
  kubernetes_network_config {
    service_ipv4_cidr = var.service_ipv4_cidr
    ip_family         = var.ip_family
  }

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
  }
}

# VPC CNI Add-on
resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "vpc-cni"
  addon_version            = var.vpc_cni_version
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = aws_iam_role.vpc_cni[0].arn

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = var.enable_prefix_delegation ? "true" : "false"
      WARM_PREFIX_TARGET       = var.warm_prefix_target
      WARM_IP_TARGET          = var.warm_ip_target
      MINIMUM_IP_TARGET       = var.minimum_ip_target
    }
  })

  tags = {
    Name        = "${var.cluster_name}-vpc-cni"
    Environment = var.environment
  }
}

# CoreDNS Add-on
resource "aws_eks_addon" "coredns" {
  cluster_name      = aws_eks_cluster.main.name
  addon_name        = "coredns"
  addon_version     = var.coredns_version
  resolve_conflicts = "OVERWRITE"

  configuration_values = jsonencode({
    computeType = var.coredns_compute_type
    resources = {
      limits = {
        cpu    = var.coredns_cpu_limit
        memory = var.coredns_memory_limit
      }
      requests = {
        cpu    = var.coredns_cpu_request
        memory = var.coredns_memory_request
      }
    }
  })

  tags = {
    Name        = "${var.cluster_name}-coredns"
    Environment = var.environment
  }
}

# kube-proxy Add-on
resource "aws_eks_addon" "kube_proxy" {
  cluster_name      = aws_eks_cluster.main.name
  addon_name        = "kube-proxy"
  addon_version     = var.kube_proxy_version
  resolve_conflicts = "OVERWRITE"

  tags = {
    Name        = "${var.cluster_name}-kube-proxy"
    Environment = var.environment
  }
}

# IAM Role for VPC CNI
resource "aws_iam_role" "vpc_cni" {
  count = var.create_vpc_cni_irsa ? 1 : 0
  name  = "${var.cluster_name}-vpc-cni-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${var.oidc_provider}:sub" = "system:serviceaccount:kube-system:aws-node"
            "${var.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-vpc-cni-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  count      = var.create_vpc_cni_irsa ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni[0].name
}

# Custom Networking Configuration
resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = var.node_group_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      }
    ])
    mapUsers = yamlencode(var.map_users)
  }
}

# Network Load Balancer for private API access
resource "aws_lb" "eks_nlb" {
  count              = var.create_private_nlb ? 1 : 0
  name               = "${var.cluster_name}-private-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids

  enable_deletion_protection = var.enable_nlb_deletion_protection

  tags = {
    Name        = "${var.cluster_name}-private-nlb"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "eks_api" {
  count    = var.create_private_nlb ? 1 : 0
  name     = "${var.cluster_name}-api-tg"
  port     = 443
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/healthz"
    port                = "traffic-port"
    protocol            = "HTTPS"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.cluster_name}-api-tg"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "eks_api" {
  count             = var.create_private_nlb ? 1 : 0
  load_balancer_arn = aws_lb.eks_nlb[0].arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_api[0].arn
  }
}