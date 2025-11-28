# Resources - Q&A

## Basic Questions

### Q1: What are Terraform resources?
**Answer:** Resources are the most important element in Terraform. They represent infrastructure objects like virtual machines, networks, DNS records, etc. Resources define what infrastructure you want to create, modify, or delete.

**Key characteristics:**
- Declared using `resource` blocks
- Have a resource type and local name
- Managed by Terraform (created, updated, deleted)
- Tracked in Terraform state
- Support lifecycle management

**Basic syntax:**
```hcl
resource "resource_type" "local_name" {
  # Configuration arguments
  argument1 = "value1"
  argument2 = "value2"
}
```

### Q2: What's the difference between resource types and resource names?
**Answer:**
```hcl
resource "aws_instance" "web_server" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
}
```

- **Resource Type**: `aws_instance` - defines what kind of infrastructure object
- **Local Name**: `web_server` - unique identifier within the configuration
- **Resource Address**: `aws_instance.web_server` - full reference to the resource

**Resource Type Components:**
- **Provider**: `aws` (before underscore)
- **Resource**: `instance` (after underscore)

### Q3: How do you reference resources in Terraform?
**Answer:**
```hcl
# Define resources
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id          # Reference VPC ID
  cidr_block = "10.0.1.0/24"
  
  tags = {
    Name = "public-subnet"
  }
}

resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id  # Reference subnet ID
  
  tags = {
    Name = "web-server"
    VPC  = aws_vpc.main.tags.Name       # Reference VPC tag
  }
}

# Reference in outputs
output "instance_ip" {
  value = aws_instance.web.public_ip
}
```

### Q4: What are resource arguments and attributes?
**Answer:**

**Arguments** - Input values you provide to configure the resource:
```hcl
resource "aws_instance" "web" {
  # These are arguments (inputs)
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  key_name      = "my-key"
  
  tags = {
    Name = "web-server"
  }
}
```

**Attributes** - Output values that Terraform learns after creating the resource:
```hcl
# These are attributes (outputs) available after creation
output "instance_details" {
  value = {
    id         = aws_instance.web.id
    public_ip  = aws_instance.web.public_ip
    private_ip = aws_instance.web.private_ip
    arn        = aws_instance.web.arn
  }
}
```

### Q5: How do you handle resource dependencies?
**Answer:**

**Implicit Dependencies** (automatic):
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id  # Implicit dependency on VPC
  cidr_block = "10.0.1.0/24"
}
```

**Explicit Dependencies** (manual):
```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  
  # Explicit dependency
  depends_on = [
    aws_security_group.web,
    aws_key_pair.deployer
  ]
}

resource "aws_security_group" "web" {
  name = "web-sg"
  # ... configuration
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/id_rsa.pub")
}
```

## Intermediate Questions

### Q6: What are resource meta-arguments and how do you use them?
**Answer:**

**count** - Create multiple similar resources:
```hcl
resource "aws_instance" "web" {
  count         = 3
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  
  tags = {
    Name = "web-server-${count.index + 1}"
  }
}

# Reference specific instances
output "first_instance_ip" {
  value = aws_instance.web[0].public_ip
}

# Reference all instances
output "all_instance_ips" {
  value = aws_instance.web[*].public_ip
}
```

**for_each** - Create resources based on map or set:
```hcl
variable "instances" {
  type = map(object({
    instance_type = string
    ami          = string
  }))
  
  default = {
    web = {
      instance_type = "t3.micro"
      ami          = "ami-12345678"
    }
    app = {
      instance_type = "t3.small"
      ami          = "ami-87654321"
    }
  }
}

resource "aws_instance" "servers" {
  for_each = var.instances
  
  ami           = each.value.ami
  instance_type = each.value.instance_type
  
  tags = {
    Name = "${each.key}-server"
    Type = each.key
  }
}

# Reference specific instance
output "web_server_ip" {
  value = aws_instance.servers["web"].public_ip
}
```

**provider** - Use alternate provider configuration:
```hcl
provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_west"
  region = "us-west-2"
}

resource "aws_instance" "east_server" {
  provider = aws.us_east
  
  ami           = "ami-12345678"
  instance_type = "t3.micro"
}

resource "aws_instance" "west_server" {
  provider = aws.us_west
  
  ami           = "ami-87654321"
  instance_type = "t3.micro"
}
```

**lifecycle** - Control resource behavior:
```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  
  lifecycle {
    # Prevent accidental deletion
    prevent_destroy = true
    
    # Create new before destroying old
    create_before_destroy = true
    
    # Ignore changes to specific attributes
    ignore_changes = [
      ami,
      user_data
    ]
  }
}
```

### Q7: How do you manage resource lifecycle and updates?
**Answer:**

**Resource Creation:**
```hcl
resource "aws_s3_bucket" "example" {
  bucket = "my-unique-bucket-name"
}

# Terraform will:
# 1. Plan the creation
# 2. Call AWS API to create bucket
# 3. Store resource info in state
```

**Resource Updates:**
```hcl
resource "aws_s3_bucket" "example" {
  bucket = "my-unique-bucket-name"
  
  # Adding versioning (in-place update)
  versioning {
    enabled = true
  }
}
```

**Resource Replacement:**
```hcl
resource "aws_instance" "web" {
  ami           = "ami-new-version"  # Changing AMI forces replacement
  instance_type = "t3.micro"
  
  lifecycle {
    create_before_destroy = true  # Create new before destroying old
  }
}
```

**Preventing Destruction:**
```hcl
resource "aws_db_instance" "production" {
  identifier = "prod-database"
  engine     = "mysql"
  
  lifecycle {
    prevent_destroy = true  # Prevents accidental deletion
  }
}
```

**Ignoring Changes:**
```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  user_data     = file("user-data.sh")
  
  lifecycle {
    ignore_changes = [
      user_data,  # Ignore changes to user data
      ami         # Ignore AMI updates
    ]
  }
}
```

### Q8: How do you handle conditional resource creation?
**Answer:**

**Using count for conditional creation:**
```hcl
variable "create_database" {
  type    = bool
  default = false
}

resource "aws_db_instance" "main" {
  count = var.create_database ? 1 : 0
  
  identifier = "myapp-db"
  engine     = "mysql"
  # ... other configuration
}

# Reference conditional resource
locals {
  db_endpoint = var.create_database ? aws_db_instance.main[0].endpoint : null
}
```

**Environment-based conditional creation:**
```hcl
variable "environment" {
  type = string
}

# Create load balancer only in production
resource "aws_lb" "main" {
  count = var.environment == "production" ? 1 : 0
  
  name               = "main-lb"
  load_balancer_type = "application"
  # ... configuration
}

# Create monitoring only for prod and staging
resource "aws_cloudwatch_dashboard" "main" {
  count = contains(["production", "staging"], var.environment) ? 1 : 0
  
  dashboard_name = "${var.environment}-dashboard"
  # ... configuration
}
```

**Feature flag pattern:**
```hcl
variable "features" {
  type = object({
    monitoring    = bool
    backup        = bool
    multi_az      = bool
  })
  
  default = {
    monitoring = false
    backup     = false
    multi_az   = false
  }
}

resource "aws_cloudwatch_alarm" "cpu" {
  count = var.features.monitoring ? 1 : 0
  
  alarm_name = "high-cpu"
  # ... configuration
}

resource "aws_db_instance" "main" {
  identifier = "myapp-db"
  multi_az   = var.features.multi_az
  
  backup_retention_period = var.features.backup ? 7 : 0
  # ... other configuration
}
```

### Q9: How do you import existing resources into Terraform?
**Answer:**

**Basic Import Process:**
```bash
# 1. Write resource configuration
# main.tf
resource "aws_instance" "existing" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  # ... other required arguments
}

# 2. Import existing resource
terraform import aws_instance.existing i-1234567890abcdef0

# 3. Verify import
terraform plan  # Should show no changes

# 4. Adjust configuration if needed
terraform plan  # Repeat until no changes
```

**Import with for_each:**
```bash
# For resources created with for_each
terraform import 'aws_instance.web["server1"]' i-1234567890abcdef0
terraform import 'aws_instance.web["server2"]' i-0987654321fedcba0
```

**Bulk Import Script:**
```bash
#!/bin/bash
# import-instances.sh

instances=(
  "web1:i-1234567890abcdef0"
  "web2:i-0987654321fedcba0"
  "app1:i-1111222233334444"
)

for instance in "${instances[@]}"; do
  name=$(echo $instance | cut -d: -f1)
  id=$(echo $instance | cut -d: -f2)
  
  echo "Importing $name with ID $id"
  terraform import "aws_instance.servers[\"$name\"]" $id
done
```

**Import State Verification:**
```bash
# Check imported resource
terraform state show aws_instance.existing

# List all resources in state
terraform state list

# Validate configuration matches state
terraform plan
```

### Q10: How do you handle resource naming and tagging?
**Answer:**

**Consistent Naming Convention:**
```hcl
locals {
  name_prefix = "${var.project}-${var.environment}"
  
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.team_name
  }
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
    Type = "networking"
  })
}

resource "aws_instance" "web" {
  count = var.instance_count
  
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-${count.index + 1}"
    Role = "webserver"
    Index = count.index + 1
  })
}
```

**Dynamic Tagging:**
```hcl
variable "additional_tags" {
  type    = map(string)
  default = {}
}

variable "cost_center" {
  type    = string
  default = null
}

locals {
  # Conditional tags
  cost_tags = var.cost_center != null ? {
    CostCenter = var.cost_center
  } : {}
  
  # Merge all tags
  final_tags = merge(
    local.common_tags,
    local.cost_tags,
    var.additional_tags
  )
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  
  tags = local.final_tags
}
```

## Advanced Questions

### Q11: How do you handle complex resource relationships?
**Answer:**

**Circular Dependencies Resolution:**
```hcl
# Problem: Circular dependency between security groups
# Solution: Use security group rules instead

resource "aws_security_group" "web" {
  name_prefix = "web-"
  vpc_id      = aws_vpc.main.id
  
  # Don't define rules here to avoid circular dependency
}

resource "aws_security_group" "app" {
  name_prefix = "app-"
  vpc_id      = aws_vpc.main.id
}

# Define rules separately
resource "aws_security_group_rule" "web_to_app" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.web.id
}

resource "aws_security_group_rule" "app_from_web" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id
  security_group_id        = aws_security_group.app.id
}
```

**Resource Ordering with depends_on:**
```hcl
resource "aws_iam_role" "lambda_role" {
  name = "lambda-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "processor" {
  filename         = "lambda.zip"
  function_name    = "data-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  
  # Ensure IAM policy is attached before creating Lambda
  depends_on = [aws_iam_role_policy_attachment.lambda_policy]
}
```

### Q12: How do you implement resource validation and constraints?
**Answer:**

**Custom Validation:**
```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  # Validation through lifecycle
  lifecycle {
    precondition {
      condition     = can(regex("^ami-", var.ami_id))
      error_message = "AMI ID must start with 'ami-'."
    }
    
    precondition {
      condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
      error_message = "Instance type must be t3.micro, t3.small, or t3.medium."
    }
  }
}
```

**Post-creation Validation:**
```hcl
resource "aws_db_instance" "main" {
  identifier = "myapp-db"
  engine     = "mysql"
  
  lifecycle {
    postcondition {
      condition     = self.status == "available"
      error_message = "Database instance is not in available state."
    }
    
    postcondition {
      condition     = self.backup_retention_period > 0
      error_message = "Backup retention must be enabled."
    }
  }
}
```

**Cross-resource Validation:**
```hcl
data "aws_vpc" "selected" {
  id = var.vpc_id
}

resource "aws_subnet" "app" {
  vpc_id     = var.vpc_id
  cidr_block = var.subnet_cidr
  
  lifecycle {
    precondition {
      condition = can(cidrsubnet(data.aws_vpc.selected.cidr_block, 8, 1))
      error_message = "Subnet CIDR must be within VPC CIDR range."
    }
  }
}
```

### Q13: How do you handle resource state management issues?
**Answer:**

**Resource Drift Detection:**
```bash
# Detect configuration drift
terraform plan -refresh-only

# Update state to match reality
terraform apply -refresh-only

# Force refresh specific resource
terraform apply -refresh-only -target=aws_instance.web
```

**State Manipulation:**
```bash
# Remove resource from state (without destroying)
terraform state rm aws_instance.old

# Move resource in state
terraform state mv aws_instance.web aws_instance.web_server

# Import existing resource
terraform import aws_instance.existing i-1234567890abcdef0

# Show resource state
terraform state show aws_instance.web
```

**Resource Replacement:**
```bash
# Force resource replacement
terraform apply -replace=aws_instance.web

# Taint resource for replacement (legacy)
terraform taint aws_instance.web
terraform apply
```

**State Recovery:**
```bash
# Backup state before operations
cp terraform.tfstate terraform.tfstate.backup

# Restore from backup if needed
cp terraform.tfstate.backup terraform.tfstate

# Pull state from remote backend
terraform state pull > local-state-backup.json
```

### Q14: What are best practices for resource management?
**Answer:**

**Resource Organization:**
```hcl
# Group related resources
# networking.tf
resource "aws_vpc" "main" { ... }
resource "aws_subnet" "public" { ... }
resource "aws_subnet" "private" { ... }
resource "aws_internet_gateway" "main" { ... }

# compute.tf
resource "aws_instance" "web" { ... }
resource "aws_autoscaling_group" "app" { ... }
resource "aws_launch_template" "app" { ... }

# security.tf
resource "aws_security_group" "web" { ... }
resource "aws_security_group" "app" { ... }
resource "aws_iam_role" "instance_role" { ... }
```

**Resource Naming:**
```hcl
# Consistent naming pattern
locals {
  resource_prefix = "${var.project}-${var.environment}"
}

resource "aws_instance" "web" {
  # Use descriptive local names
  tags = {
    Name = "${local.resource_prefix}-web-server"
  }
}

resource "aws_db_instance" "main" {
  identifier = "${local.resource_prefix}-database"
}
```

**Resource Documentation:**
```hcl
resource "aws_instance" "web" {
  # Purpose: Web server for application frontend
  # Dependencies: Requires VPC and security group
  # Lifecycle: Can be replaced without data loss
  
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id
  
  # Security group for HTTP/HTTPS traffic
  vpc_security_group_ids = [aws_security_group.web.id]
  
  tags = {
    Name        = "${local.resource_prefix}-web"
    Purpose     = "Frontend web server"
    Backup      = "not-required"
    Monitoring  = "basic"
  }
}
```

**Error Handling:**
```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  # Graceful handling of optional resources
  key_name = var.key_pair_name != "" ? var.key_pair_name : null
  
  # Default values for optional configurations
  monitoring                = var.detailed_monitoring
  associate_public_ip_address = var.environment != "production"
  
  lifecycle {
    # Prevent accidental deletion in production
    prevent_destroy = var.environment == "production"
    
    # Handle AMI updates gracefully
    create_before_destroy = true
    
    ignore_changes = [
      # Ignore changes managed outside Terraform
      user_data,
      security_groups
    ]
  }
}
```

### Q15: How do you troubleshoot resource issues?
**Answer:**

**Common Resource Issues:**

**1. Resource Creation Failures:**
```bash
# Enable detailed logging
export TF_LOG=DEBUG
terraform apply

# Check specific resource
terraform plan -target=aws_instance.web

# Validate configuration
terraform validate
```

**2. Dependency Issues:**
```bash
# Visualize dependencies
terraform graph | dot -Tpng > graph.png

# Check resource order
terraform plan -out=plan.out
terraform show -json plan.out | jq '.planned_values.root_module.resources'
```

**3. State Inconsistencies:**
```bash
# Refresh state
terraform refresh

# Compare state with reality
terraform plan -refresh-only

# Fix state manually if needed
terraform state rm aws_instance.broken
terraform import aws_instance.fixed i-1234567890abcdef0
```

**4. Resource Conflicts:**
```hcl
# Handle resource conflicts with random naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "app" {
  bucket = "${var.app_name}-${random_string.suffix.result}"
}
```

**5. Debugging Resource Attributes:**
```hcl
# Use outputs for debugging
output "debug_instance" {
  value = {
    id              = aws_instance.web.id
    state           = aws_instance.web.instance_state
    public_ip       = aws_instance.web.public_ip
    security_groups = aws_instance.web.security_groups
  }
}

# Use locals for intermediate values
locals {
  debug_info = {
    vpc_id    = aws_vpc.main.id
    subnet_id = aws_subnet.public.id
    sg_id     = aws_security_group.web.id
  }
}

output "debug_networking" {
  value = local.debug_info
}
```