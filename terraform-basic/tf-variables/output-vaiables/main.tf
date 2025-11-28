# Output Variables Examples

# Simple String Output
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.example.id
}

# Number Output
output "instance_count" {
  description = "Number of instances created"
  value       = length(aws_instance.example)
}

# List Output
output "instance_ids" {
  description = "List of instance IDs"
  value       = aws_instance.example[*].id
}

# Map Output
output "instance_details" {
  description = "Map of instance details"
  value = {
    for i, instance in aws_instance.example : 
    "instance-${i}" => {
      id                = instance.id
      public_ip         = instance.public_ip
      private_ip        = instance.private_ip
      availability_zone = instance.availability_zone
    }
  }
}

# Sensitive Output
output "db_endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.example.endpoint
  sensitive   = true
}

# Conditional Output
output "load_balancer_dns" {
  description = "Load balancer DNS name"
  value       = var.create_load_balancer ? aws_lb.example[0].dns_name : null
}

# Complex Object Output
output "network_configuration" {
  description = "Network configuration details"
  value = {
    vpc = {
      id         = aws_vpc.example.id
      cidr_block = aws_vpc.example.cidr_block
    }
    subnets = {
      for subnet in aws_subnet.example :
      subnet.tags.Name => {
        id                = subnet.id
        cidr_block        = subnet.cidr_block
        availability_zone = subnet.availability_zone
      }
    }
    security_groups = {
      for sg in aws_security_group.example :
      sg.name => {
        id          = sg.id
        description = sg.description
      }
    }
  }
}

# Output with Depends On
output "application_url" {
  description = "Application URL"
  value       = "http://${aws_lb.example[0].dns_name}"
  depends_on  = [aws_lb_listener.example]
}

# JSON Output
output "tags_json" {
  description = "Tags in JSON format"
  value       = jsonencode(var.tags)
}

# Output for Cross-Stack Reference
output "vpc_info" {
  description = "VPC information for cross-stack reference"
  value = {
    vpc_id             = aws_vpc.example.id
    public_subnet_ids  = [for subnet in aws_subnet.public : subnet.id]
    private_subnet_ids = [for subnet in aws_subnet.private : subnet.id]
    security_group_id  = aws_security_group.example.id
  }
}

# Resources for Output Examples
resource "aws_vpc" "example" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "example-vpc"
  }
}

resource "aws_subnet" "example" {
  count             = 2
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "example-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.${count.index + 10}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.${count.index + 20}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${count.index + 1}"
    Type = "Private"
  }
}

resource "aws_security_group" "example" {
  name_prefix = "example-"
  vpc_id      = aws_vpc.example.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "example-sg"
  }
}

resource "aws_instance" "example" {
  count           = 2
  ami             = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public[count.index].id
  security_groups = [aws_security_group.example.id]

  tags = {
    Name = "example-instance-${count.index + 1}"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}