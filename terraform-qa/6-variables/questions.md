# Variables - Q&A

## Basic Questions

### Q1: What are Terraform variables and why are they important?
**Answer:** Terraform variables are parameters that allow you to customize and reuse your configurations without hardcoding values. They make your infrastructure code flexible, reusable, and maintainable.

**Types of variables:**
- **Input Variables** (`variable`): Accept values from outside the configuration
- **Local Variables** (`locals`): Computed values used within the configuration  
- **Output Variables** (`output`): Return values from the configuration

**Benefits:**
- Code reusability across environments
- Parameterization of configurations
- Separation of configuration from values
- Enhanced security (sensitive variables)
- Better maintainability

### Q2: How do you define input variables in Terraform?
**Answer:**
```hcl
# Basic variable definition
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

# Variable with validation
variable "environment" {
  description = "Environment name"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# Sensitive variable
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# Variable without default (required)
variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}
```

### Q3: What are the different variable types in Terraform?
**Answer:**

**Primitive Types:**
```hcl
variable "instance_count" {
  type = number
  default = 2
}

variable "enable_monitoring" {
  type = bool
  default = true
}

variable "app_name" {
  type = string
  default = "myapp"
}
```

**Collection Types:**
```hcl
# List
variable "availability_zones" {
  type = list(string)
  default = ["us-west-2a", "us-west-2b"]
}

# Set (unique values)
variable "allowed_cidrs" {
  type = set(string)
  default = ["10.0.0.0/8", "172.16.0.0/12"]
}

# Map
variable "instance_types" {
  type = map(string)
  default = {
    dev  = "t3.micro"
    prod = "t3.large"
  }
}
```

**Structural Types:**
```hcl
# Object
variable "database_config" {
  type = object({
    engine         = string
    engine_version = string
    instance_class = string
    allocated_storage = number
    encrypted      = bool
  })
  
  default = {
    engine         = "mysql"
    engine_version = "8.0"
    instance_class = "db.t3.micro"
    allocated_storage = 20
    encrypted      = true
  }
}

# Tuple
variable "subnet_configs" {
  type = tuple([string, string, bool])
  default = ["10.0.1.0/24", "us-west-2a", true]
}
```

### Q4: How do you assign values to variables?
**Answer:**

**1. Command Line:**
```bash
terraform apply -var="instance_type=t3.large" -var="environment=prod"
```

**2. Variable Files (.tfvars):**
```hcl
# terraform.tfvars
instance_type = "t3.large"
environment   = "prod"
vpc_cidr      = "10.0.0.0/16"

# List values
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

# Map values
tags = {
  Environment = "production"
  Project     = "myapp"
}
```

**3. Environment Variables:**
```bash
export TF_VAR_instance_type="t3.large"
export TF_VAR_environment="prod"
terraform apply
```

**4. Auto-loaded Files:**
- `terraform.tfvars`
- `terraform.tfvars.json`
- `*.auto.tfvars`
- `*.auto.tfvars.json`

**5. Interactive Input:**
```bash
# Terraform will prompt for missing variables
terraform apply
```

### Q5: What are local variables and how do you use them?
**Answer:**
```hcl
locals {
  # Simple computed values
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
  
  # Conditional logic
  instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"
  
  # String interpolation
  bucket_name = "${var.project_name}-${var.environment}-${random_string.suffix.result}"
  
  # Complex computations
  subnet_cidrs = [
    for i in range(var.subnet_count) : 
    cidrsubnet(var.vpc_cidr, 8, i)
  ]
  
  # Flattening nested structures
  security_rules = flatten([
    for sg_name, sg_config in var.security_groups : [
      for rule in sg_config.rules : {
        sg_name   = sg_name
        from_port = rule.from_port
        to_port   = rule.to_port
        protocol  = rule.protocol
        cidr_blocks = rule.cidr_blocks
      }
    ]
  ])
}

# Using locals in resources
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = local.instance_type
  tags          = local.common_tags
}
```

## Intermediate Questions

### Q6: How do you implement variable validation?
**Answer:**
```hcl
# String validation with regex
variable "instance_type" {
  type = string
  
  validation {
    condition = can(regex("^t3\\.(micro|small|medium|large)$", var.instance_type))
    error_message = "Instance type must be t3.micro, t3.small, t3.medium, or t3.large."
  }
}

# Number validation
variable "port" {
  type = number
  
  validation {
    condition     = var.port >= 1 && var.port <= 65535
    error_message = "Port must be between 1 and 65535."
  }
}

# List validation
variable "availability_zones" {
  type = list(string)
  
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones must be specified."
  }
}

# Complex validation
variable "database_config" {
  type = object({
    engine      = string
    version     = string
    multi_az    = bool
    storage_gb  = number
  })
  
  validation {
    condition = contains(["mysql", "postgres"], var.database_config.engine)
    error_message = "Database engine must be mysql or postgres."
  }
  
  validation {
    condition = var.database_config.storage_gb >= 20 && var.database_config.storage_gb <= 1000
    error_message = "Storage must be between 20 and 1000 GB."
  }
}

# Multiple conditions
variable "environment" {
  type = string
  
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
  
  validation {
    condition = length(var.environment) <= 10
    error_message = "Environment name must be 10 characters or less."
  }
}
```

### Q7: How do you handle sensitive variables?
**Answer:**
```hcl
# Define sensitive variable
variable "database_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "api_keys" {
  description = "API keys for external services"
  type = map(string)
  sensitive = true
  default = {}
}

# Using sensitive variables
resource "aws_db_instance" "main" {
  password = var.database_password
  # Other configuration...
}

# Sensitive locals
locals {
  db_connection_string = "mysql://${var.db_username}:${var.database_password}@${aws_db_instance.main.endpoint}"
}

# Mark local as sensitive
locals {
  sensitive_config = sensitive({
    api_key = var.api_keys["external_service"]
    token   = random_password.api_token.result
  })
}

# Sensitive outputs
output "database_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "database_connection" {
  value     = local.db_connection_string
  sensitive = true
}
```

### Q8: How do you use variables with for_each and count?
**Answer:**
```hcl
# Using variables with count
variable "instance_count" {
  type    = number
  default = 3
}

resource "aws_instance" "web" {
  count         = var.instance_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  
  tags = {
    Name = "web-${count.index + 1}"
  }
}

# Using variables with for_each (map)
variable "environments" {
  type = map(object({
    instance_type = string
    min_size      = number
    max_size      = number
  }))
  
  default = {
    dev = {
      instance_type = "t3.micro"
      min_size      = 1
      max_size      = 2
    }
    prod = {
      instance_type = "t3.large"
      min_size      = 3
      max_size      = 10
    }
  }
}

resource "aws_autoscaling_group" "app" {
  for_each = var.environments
  
  name             = "${each.key}-asg"
  min_size         = each.value.min_size
  max_size         = each.value.max_size
  desired_capacity = each.value.min_size
  
  launch_template {
    id      = aws_launch_template.app[each.key].id
    version = "$Latest"
  }
}

# Using variables with for_each (set)
variable "subnet_cidrs" {
  type = set(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

resource "aws_subnet" "private" {
  for_each = var.subnet_cidrs
  
  vpc_id     = aws_vpc.main.id
  cidr_block = each.value
  
  tags = {
    Name = "private-${each.value}"
  }
}
```

### Q9: How do you implement conditional logic with variables?
**Answer:**
```hcl
# Conditional resource creation
variable "create_database" {
  type    = bool
  default = false
}

resource "aws_db_instance" "main" {
  count = var.create_database ? 1 : 0
  
  identifier = "myapp-db"
  engine     = "mysql"
  # Other configuration...
}

# Conditional values using ternary operator
variable "environment" {
  type = string
}

locals {
  instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"
  
  storage_encrypted = var.environment == "prod" ? true : false
  
  backup_retention = var.environment == "prod" ? 30 : 7
}

# Complex conditional logic
variable "high_availability" {
  type    = bool
  default = false
}

variable "environment" {
  type = string
}

locals {
  # Multiple conditions
  instance_count = var.environment == "prod" && var.high_availability ? 5 : (
    var.environment == "prod" ? 3 : 1
  )
  
  # Conditional map values
  tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.environment == "prod" ? {
      Backup      = "required"
      Monitoring  = "enhanced"
    } : {}
  )
}

# Using try() for safe conditionals
variable "optional_config" {
  type = object({
    enabled = bool
    value   = string
  })
  default = null
}

locals {
  config_value = try(var.optional_config.value, "default-value")
  config_enabled = try(var.optional_config.enabled, false)
}
```

### Q10: How do you organize variables across multiple files?
**Answer:**

**File Structure:**
```
├── variables.tf          # Main variable definitions
├── terraform.tfvars      # Default values
├── environments/
│   ├── dev.tfvars        # Development values
│   ├── staging.tfvars    # Staging values
│   └── prod.tfvars       # Production values
└── modules/
    └── vpc/
        ├── variables.tf  # Module-specific variables
        └── outputs.tf
```

**variables.tf:**
```hcl
# Infrastructure variables
variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

# Application variables
variable "app_name" {
  description = "Application name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# Feature flags
variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring"
  type        = bool
  default     = true
}
```

**environments/prod.tfvars:**
```hcl
region      = "us-west-2"
vpc_cidr    = "10.0.0.0/16"
app_name    = "myapp"
environment = "prod"

# Production-specific settings
enable_monitoring = true
instance_type     = "t3.large"
min_capacity      = 3
max_capacity      = 10
```

**Usage:**
```bash
terraform apply -var-file="environments/prod.tfvars"
```

## Advanced Questions

### Q11: How do you implement variable inheritance and composition?
**Answer:**
```hcl
# Base configuration
variable "base_config" {
  type = object({
    region            = string
    availability_zones = list(string)
    common_tags       = map(string)
  })
}

# Environment-specific overrides
variable "environment_config" {
  type = object({
    instance_type = string
    min_size      = number
    max_size      = number
    storage_size  = number
  })
}

# Merge configurations
locals {
  # Merge base and environment configs
  merged_config = merge(
    var.base_config,
    var.environment_config,
    {
      # Additional computed values
      name_prefix = "${var.base_config.common_tags.Project}-${var.environment}"
    }
  )
  
  # Inherit and extend tags
  instance_tags = merge(
    var.base_config.common_tags,
    {
      Environment = var.environment
      InstanceType = var.environment_config.instance_type
    }
  )
}
```

### Q12: How do you implement dynamic variable validation?
**Answer:**
```hcl
# Dynamic validation based on other variables
variable "instance_type" {
  type = string
}

variable "environment" {
  type = string
}

variable "storage_size" {
  type = number
  
  validation {
    # Dynamic validation based on environment
    condition = (
      var.environment == "prod" ? var.storage_size >= 100 : var.storage_size >= 20
    )
    error_message = "Production requires at least 100GB, non-prod requires at least 20GB."
  }
}

# Cross-variable validation
variable "backup_config" {
  type = object({
    enabled           = bool
    retention_days    = number
    cross_region_copy = bool
  })
  
  validation {
    condition = (
      var.backup_config.enabled == false ? true : var.backup_config.retention_days > 0
    )
    error_message = "When backup is enabled, retention_days must be greater than 0."
  }
  
  validation {
    condition = (
      var.backup_config.cross_region_copy == true ? var.backup_config.enabled == true : true
    )
    error_message = "Cross-region copy requires backup to be enabled."
  }
}
```

### Q13: How do you handle complex variable transformations?
**Answer:**
```hcl
# Input variable with complex structure
variable "applications" {
  type = map(object({
    port        = number
    protocol    = string
    health_path = string
    replicas    = number
    resources = object({
      cpu    = string
      memory = string
    })
  }))
}

# Transform variables for different use cases
locals {
  # Flatten for security group rules
  security_rules = flatten([
    for app_name, app_config in var.applications : [
      {
        app_name    = app_name
        port        = app_config.port
        protocol    = app_config.protocol
        description = "Allow ${app_config.protocol} traffic for ${app_name}"
      }
    ]
  ])
  
  # Transform for load balancer targets
  lb_targets = {
    for app_name, app_config in var.applications : app_name => {
      port                = app_config.port
      protocol            = upper(app_config.protocol)
      health_check_path   = app_config.health_path
      health_check_port   = app_config.port
    }
  }
  
  # Calculate total resources
  total_cpu = sum([
    for app_name, app_config in var.applications :
    tonumber(replace(app_config.resources.cpu, "m", "")) * app_config.replicas
  ])
  
  # Group by resource requirements
  resource_groups = {
    for app_name, app_config in var.applications : app_name => {
      size = (
        tonumber(replace(app_config.resources.cpu, "m", "")) > 500 ||
        tonumber(replace(app_config.resources.memory, "Mi", "")) > 1024
      ) ? "large" : "small"
    }
  }
}
```

### Q14: What are best practices for variable management?
**Answer:**

**Naming Conventions:**
```hcl
# Good naming practices
variable "vpc_cidr_block" {          # Descriptive and specific
  description = "CIDR block for VPC"
  type        = string
}

variable "enable_nat_gateway" {      # Boolean prefix with "enable_"
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "instance_types_by_env" {   # Clear relationship
  description = "Instance types mapped by environment"
  type        = map(string)
}
```

**Documentation:**
```hcl
variable "database_config" {
  description = <<-EOT
    Database configuration object containing:
    - engine: Database engine (mysql, postgres)
    - version: Engine version (e.g., "8.0", "13.7")
    - instance_class: RDS instance class (e.g., "db.t3.micro")
    - allocated_storage: Storage size in GB (minimum 20)
    - multi_az: Enable Multi-AZ deployment for high availability
    - backup_retention_period: Backup retention in days (0-35)
  EOT
  
  type = object({
    engine                  = string
    version                = string
    instance_class         = string
    allocated_storage      = number
    multi_az              = bool
    backup_retention_period = number
  })
}
```

**Security:**
```hcl
# Mark sensitive variables
variable "database_password" {
  description = "Master password for RDS instance"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.database_password) >= 8
    error_message = "Password must be at least 8 characters long."
  }
}

# Use separate files for sensitive values
# secrets.auto.tfvars (not in version control)
database_password = "super-secret-password"
api_key          = "secret-api-key"
```

**Organization:**
```hcl
# Group related variables
# Network variables
variable "vpc_cidr" { ... }
variable "public_subnet_cidrs" { ... }
variable "private_subnet_cidrs" { ... }

# Compute variables  
variable "instance_type" { ... }
variable "key_pair_name" { ... }
variable "user_data_script" { ... }

# Database variables
variable "db_engine" { ... }
variable "db_instance_class" { ... }
variable "db_allocated_storage" { ... }
```

### Q15: How do you troubleshoot variable-related issues?
**Answer:**

**Common Issues and Solutions:**

**1. Variable Type Mismatches:**
```hcl
# Problem: Passing string to number variable
variable "instance_count" {
  type = number
}

# Solution: Use type conversion
locals {
  instance_count = tonumber(var.instance_count_string)
}
```

**2. Missing Required Variables:**
```bash
# Error: No value for required variable
terraform apply

# Solution: Provide value
terraform apply -var="vpc_id=vpc-12345"
```

**3. Validation Failures:**
```hcl
# Debug validation with locals
locals {
  debug_validation = {
    input_value = var.instance_type
    is_valid    = contains(["t3.micro", "t3.small"], var.instance_type)
    valid_options = ["t3.micro", "t3.small"]
  }
}

output "debug_info" {
  value = local.debug_validation
}
```

**4. Complex Variable Debugging:**
```hcl
# Use outputs to debug variable transformations
output "debug_variables" {
  value = {
    original_input = var.complex_config
    transformed    = local.processed_config
    flattened     = local.flattened_rules
  }
}
```

**5. Variable Precedence Issues:**
```bash
# Check variable precedence
terraform console
> var.instance_type

# Verify variable files are loaded
terraform plan -var-file="custom.tfvars"
```