# Local Values Examples

# Simple Local Values
locals {
  project_name = "terraform-demo"
  environment  = "dev"
  region       = "us-east-1"
}

# Computed Local Values
locals {
  # Combine variables to create names
  vpc_name = "${local.project_name}-${local.environment}-vpc"
  
  # Common tags used across resources
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  }
  
  # Conditional logic
  instance_type = local.environment == "prod" ? "t3.medium" : "t2.micro"
  
  # Calculate values
  subnet_count = length(var.availability_zones)
  
  # String manipulation
  bucket_name = lower("${local.project_name}-${local.environment}-${random_id.bucket_suffix.hex}")
}

# Complex Local Values
locals {
  # Create subnet configurations
  public_subnets = [
    for i, az in var.availability_zones : {
      name              = "public-subnet-${i + 1}"
      cidr_block        = cidrsubnet(var.vpc_cidr, 8, i)
      availability_zone = az
      public            = true
    }
  ]
  
  private_subnets = [
    for i, az in var.availability_zones : {
      name              = "private-subnet-${i + 1}"
      cidr_block        = cidrsubnet(var.vpc_cidr, 8, i + 10)
      availability_zone = az
      public            = false
    }
  ]
  
  # Merge all subnets
  all_subnets = concat(local.public_subnets, local.private_subnets)
}

# Local Values with Functions
locals {
  # File content
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    project_name = local.project_name
    environment  = local.environment
  }))
  
  # JSON configuration
  app_config = jsonencode({
    database = {
      host     = aws_db_instance.main.endpoint
      port     = aws_db_instance.main.port
      name     = aws_db_instance.main.db_name
    }
    cache = {
      endpoint = aws_elasticache_cluster.main.cache_nodes[0].address
      port     = aws_elasticache_cluster.main.cache_nodes[0].port
    }
  })
  
  # Security group rules
  web_ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS"
    }
  ]
}

# Environment-specific Local Values
locals {
  # Different configurations per environment
  env_config = {
    dev = {
      instance_count = 1
      instance_type  = "t2.micro"
      db_instance_class = "db.t3.micro"
      enable_backup  = false
    }
    staging = {
      instance_count = 2
      instance_type  = "t3.small"
      db_instance_class = "db.t3.small"
      enable_backup  = true
    }
    prod = {
      instance_count = 3
      instance_type  = "t3.medium"
      db_instance_class = "db.t3.medium"
      enable_backup  = true
    }
  }
  
  # Select configuration based on environment
  current_config = local.env_config[local.environment]
}

# Using Local Values in Resources
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = local.vpc_name
  })
}

resource "aws_subnet" "public" {
  count                   = length(local.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[count.index].cidr_block
  availability_zone       = local.public_subnets[count.index].availability_zone
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = local.public_subnets[count.index].name
    Type = "Public"
  })
}

resource "aws_subnet" "private" {
  count             = length(local.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index].cidr_block
  availability_zone = local.private_subnets[count.index].availability_zone

  tags = merge(local.common_tags, {
    Name = local.private_subnets[count.index].name
    Type = "Private"
  })
}

resource "aws_security_group" "web" {
  name_prefix = "${local.project_name}-web-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for web servers"

  dynamic "ingress" {
    for_each = local.web_ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-web-sg"
  })
}

resource "aws_instance" "web" {
  count                  = local.current_config.instance_count
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = local.current_config.instance_type
  subnet_id              = aws_subnet.public[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids = [aws_security_group.web.id]
  user_data              = local.user_data

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-web-${count.index + 1}"
  })
}

resource "aws_s3_bucket" "main" {
  bucket        = local.bucket_name
  force_destroy = true

  tags = local.common_tags
}

# Variables used in locals
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Random resource for unique naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Data sources
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Example resources referenced in locals
resource "aws_db_instance" "main" {
  identifier     = "${local.project_name}-${local.environment}-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = local.current_config.db_instance_class
  allocated_storage = 20
  
  db_name  = "myapp"
  username = "admin"
  password = "changeme123!"
  
  skip_final_snapshot = true
  
  tags = local.common_tags
}

resource "aws_elasticache_cluster" "main" {
  cluster_id           = "${local.project_name}-${local.environment}-cache"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  
  tags = local.common_tags
}