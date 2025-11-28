# Input Variables Examples

# String Variable
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

# Number Variable
variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 1
}

# Boolean Variable
variable "enable_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = false
}

# List Variable
variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# Map Variable
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "terraform-demo"
  }
}

# Object Variable
variable "vpc_config" {
  description = "VPC configuration"
  type = object({
    cidr_block           = string
    enable_dns_hostnames = bool
    enable_dns_support   = bool
  })
  default = {
    cidr_block           = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support   = true
  }
}

# Variable with Validation
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# Sensitive Variable
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# Variable with Multiple Validations
variable "instance_size" {
  description = "Instance size configuration"
  type        = string
  default     = "small"
  
  validation {
    condition     = contains(["small", "medium", "large"], var.instance_size)
    error_message = "Instance size must be small, medium, or large."
  }
}

# Complex List of Objects
variable "subnets" {
  description = "List of subnet configurations"
  type = list(object({
    name              = string
    cidr_block        = string
    availability_zone = string
    public            = bool
  }))
  default = [
    {
      name              = "public-subnet-1"
      cidr_block        = "10.0.1.0/24"
      availability_zone = "us-east-1a"
      public            = true
    },
    {
      name              = "private-subnet-1"
      cidr_block        = "10.0.2.0/24"
      availability_zone = "us-east-1b"
      public            = false
    }
  ]
}

# Using Variables in Resources
resource "aws_instance" "example" {
  count                  = var.instance_count
  ami                    = "ami-0abcdef1234567890"
  instance_type          = var.instance_type
  availability_zone      = var.availability_zones[count.index % length(var.availability_zones)]
  monitoring             = var.enable_monitoring

  tags = merge(var.tags, {
    Name = "instance-${count.index + 1}"
  })
}

resource "aws_vpc" "example" {
  cidr_block           = var.vpc_config.cidr_block
  enable_dns_hostnames = var.vpc_config.enable_dns_hostnames
  enable_dns_support   = var.vpc_config.enable_dns_support

  tags = var.tags
}