# EKS Cluster Security Group
resource "aws_security_group" "eks_cluster" {
  name_prefix = "${var.project_name}-eks-cluster-"
  vpc_id      = var.vpc_id
  description = "Security group for EKS cluster control plane"

  ingress {
    description = "HTTPS from worker nodes"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-eks-cluster-sg"
    Environment = var.environment
  }
}

# EKS Node Group Security Group
resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.project_name}-eks-nodes-"
  vpc_id      = var.vpc_id
  description = "Security group for EKS worker nodes"

  ingress {
    description = "Node to node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Pod to pod communication"
    from_port   = 1025
    to_port     = 65535
    protocol    = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  ingress {
    description = "HTTPS from cluster"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr_blocks
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                        = "${var.project_name}-eks-nodes-sg"
    Environment                                 = var.environment
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# Additional Security Group for ALB Ingress Controller
resource "aws_security_group" "alb_ingress" {
  count       = var.enable_alb_ingress ? 1 : 0
  name_prefix = "${var.project_name}-alb-ingress-"
  vpc_id      = var.vpc_id
  description = "Security group for ALB Ingress Controller"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-ingress-sg"
    Environment = var.environment
  }
}

# KMS Key for EKS Secrets Encryption
resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS secrets encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EKS Service"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-eks-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.project_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# Network Policy (Calico) - ConfigMap
resource "kubernetes_config_map" "calico_config" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "calico-config"
    namespace = "kube-system"
  }

  data = {
    "calico_backend" = "bird"
    "cluster_type"   = "k8s,bgp"
    "cni_network_config" = jsonencode({
      name = "k8s-pod-network"
      cniVersion = "0.3.1"
      plugins = [
        {
          type = "calico"
          log_level = "info"
          datastore_type = "kubernetes"
          nodename = "__KUBERNETES_NODE_NAME__"
          mtu = "__CNI_MTU__"
          ipam = {
            type = "calico-ipam"
          }
          policy = {
            type = "k8s"
          }
          kubernetes = {
            kubeconfig = "__KUBECONFIG_FILEPATH__"
          }
        },
        {
          type = "portmap"
          snat = true
          capabilities = {
            portMappings = true
          }
        }
      ]
    })
  }
}

# Pod Security Policy
resource "kubernetes_pod_security_policy" "restricted" {
  count = var.enable_pod_security_policy ? 1 : 0

  metadata {
    name = "${var.project_name}-restricted-psp"
  }

  spec {
    privileged                 = false
    allow_privilege_escalation = false
    required_drop_capabilities = ["ALL"]
    volumes = [
      "configMap",
      "emptyDir",
      "projected",
      "secret",
      "downwardAPI",
      "persistentVolumeClaim"
    ]

    run_as_user {
      rule = "MustRunAsNonRoot"
    }

    se_linux {
      rule = "RunAsAny"
    }

    fs_group {
      rule = "RunAsAny"
    }
  }
}

# RBAC for Pod Security Policy
resource "kubernetes_cluster_role" "psp_restricted" {
  count = var.enable_pod_security_policy ? 1 : 0

  metadata {
    name = "${var.project_name}-psp-restricted"
  }

  rule {
    api_groups     = ["policy"]
    resources      = ["podsecuritypolicies"]
    verbs          = ["use"]
    resource_names = [kubernetes_pod_security_policy.restricted[0].metadata[0].name]
  }
}

resource "kubernetes_cluster_role_binding" "psp_restricted" {
  count = var.enable_pod_security_policy ? 1 : 0

  metadata {
    name = "${var.project_name}-psp-restricted"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.psp_restricted[0].metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "system:authenticated"
    api_group = "rbac.authorization.k8s.io"
  }
}

# Network Policy Example
resource "kubernetes_network_policy" "deny_all" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "deny-all"
    namespace = "default"
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

resource "kubernetes_network_policy" "allow_same_namespace" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "allow-same-namespace"
    namespace = "default"
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "default"
          }
        }
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "default"
          }
        }
      }
    }
  }
}

data "aws_caller_identity" "current" {}