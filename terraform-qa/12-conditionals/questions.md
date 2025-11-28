# Terraform Conditionals - Q&A

## Basic Questions

### Q1: What are conditionals in Terraform?
**Answer:** Conditionals in Terraform allow you to make decisions in your configuration based on input variables, resource attributes, or other conditions. They enable dynamic behavior and resource creation based on different scenarios.

### Q2: What is the basic syntax for conditional expressions?
**Answer:** Terraform uses the ternary operator syntax: `condition ? true_value : false_value`
```hcl
locals {
  instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"
  enable_backup = var.environment == "prod" ? true : false
}
```

### Q3: How do you create resources conditionally?
**Answer:** Use the `count` parameter with conditional expressions:
```hcl
resource "aws_instance" "web" {
  count = var.create_instance ? 1 : 0
  
  ami           = "ami-12345678"
  instance_type = "t3.micro"
}
```

## Intermediate Questions

### Q4: How do you use conditional expressions with different data types?
**Answer:** 
```hcl
locals {
  # String conditional
  environment_name = var.env == "p" ? "production" : "development"
  
  # Number conditional
  instance_count = var.high_availability ? 3 : 1
  
  # List conditional
  availability_zones = var.multi_az ? ["us-east-1a", "us-east-1b"] : ["us-east-1a"]
  
  # Map conditional
  tags = var.environment == "prod" ? {
    Environment = "production"
    Backup = "daily"
  } : {
    Environment = "development"
    Backup = "none"
  }
}
```

### Q5: What is the difference between count and for_each for conditional resources?
**Answer:** 
- **count**: Creates 0 or more identical resources, indexed by number
- **for_each**: Creates resources based on a map or set, indexed by key
```hcl
# Using count
resource "aws_instance" "web" {
  count = var.create_web_servers ? var.instance_count : 0
  # ...
}

# Using for_each
resource "aws_instance" "web" {
  for_each = var.create_web_servers ? var.instance_configs : {}
  # ...
}
```

### Q6: How do you implement multiple conditions?
**Answer:** 
```hcl
locals {
  # Multiple AND conditions
  create_database = var.environment == "prod" && var.enable_database
  
  # Multiple OR conditions
  enable_monitoring = var.environment == "prod" || var.environment == "staging"
  
  # Complex nested conditions
  instance_type = (
    var.environment == "prod" ? "t3.large" :
    var.environment == "staging" ? "t3.medium" :
    "t3.micro"
  )
  
  # Using contains() for multiple values
  is_production_like = contains(["prod", "production", "live"], var.environment)
}
```

### Q7: How do you use dynamic blocks with conditionals?
**Answer:** 
```hcl
resource "aws_security_group" "web" {
  name_prefix = "web-"
  vpc_id      = var.vpc_id
  
  # Conditional ingress rules
  dynamic "ingress" {
    for_each = var.allow_ssh ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  
  # Multiple conditional rules
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = var.environment == "prod" ? ["10.0.0.0/8"] : ["0.0.0.0/0"]
    }
  }
}
```

## Advanced Questions

### Q8: How do you handle null values in conditionals?
**Answer:** 
```hcl
locals {
  # Check for null
  vpc_id = var.vpc_id != null ? var.vpc_id : aws_vpc.default.id
  
  # Using coalesce for null handling
  instance_name = coalesce(var.instance_name, "default-instance")
  
  # Using try() for error handling
  subnet_id = try(var.subnet_id, aws_subnet.default.id)
  
  # Complex null checking
  database_config = var.database_config != null ? var.database_config : {
    engine = "mysql"
    version = "8.0"
  }
}
```

### Q9: How do you implement conditional validation?
**Answer:** 
```hcl
variable "environment" {
  type = string
  
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_type" {
  type = string
  
  validation {
    condition = (
      var.environment == "prod" ? 
      contains(["t3.large", "t3.xlarge"], var.instance_type) :
      contains(["t3.micro", "t3.small"], var.instance_type)
    )
    error_message = "Instance type not allowed for this environment."
  }
}
```

### Q10: How do you use conditionals with modules?
**Answer:** 
```hcl
# Conditional module inclusion
module "database" {
  count = var.create_database ? 1 : 0
  
  source = "./modules/database"
  
  instance_class = var.environment == "prod" ? "db.t3.medium" : "db.t3.micro"
  backup_retention = var.environment == "prod" ? 7 : 1
}

# Conditional module parameters
module "vpc" {
  source = "./modules/vpc"
  
  enable_nat_gateway = var.environment != "dev"
  enable_vpn_gateway = var.environment == "prod"
  
  # Conditional subnet configuration
  private_subnets = var.multi_az ? [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24"
  ] : [
    "10.0.1.0/24"
  ]
}
```

### Q11: How do you implement environment-specific configurations?
**Answer:** 
```hcl
locals {
  # Environment-specific configurations
  env_config = {
    dev = {
      instance_count = 1
      instance_type = "t3.micro"
      enable_backup = false
      db_instance_class = "db.t3.micro"
    }
    staging = {
      instance_count = 2
      instance_type = "t3.small"
      enable_backup = true
      db_instance_class = "db.t3.small"
    }
    prod = {
      instance_count = 3
      instance_type = "t3.large"
      enable_backup = true
      db_instance_class = "db.t3.large"
    }
  }
  
  # Select configuration
  config = local.env_config[var.environment]
}

resource "aws_instance" "web" {
  count = local.config.instance_count
  
  ami           = data.aws_ami.amazon_linux.id
  instance_type = local.config.instance_type
}
```

### Q12: What are best practices for conditionals?
**Answer:** 
- Keep conditions simple and readable
- Use locals to store complex conditional logic
- Prefer explicit conditions over implicit ones
- Use validation rules to catch invalid combinations
- Document complex conditional logic
- Use consistent naming for boolean variables
- Avoid deeply nested conditionals

### Q13: How do you debug conditional expressions?
**Answer:** 
```hcl
# Add debug outputs
output "debug_condition" {
  value = {
    environment = var.environment
    is_prod = var.environment == "prod"
    instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"
  }
}

# Use terraform console
# terraform console
# > var.environment == "prod"
# > local.config
```

### Q14: What are common conditional anti-patterns?
**Answer:** 
- Using count with complex resources (prefer for_each)
- Deeply nested ternary operators
- Not handling null values properly
- Using conditionals in resource names (causes recreation)
- Complex boolean logic without documentation
- Not using validation rules for input validation

### Q15: How do you handle conditional dependencies?
**Answer:** 
```hcl
# Conditional explicit dependencies
resource "aws_instance" "web" {
  count = var.create_instance ? 1 : 0
  
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  
  depends_on = var.create_database ? [aws_db_instance.main[0]] : []
}

# Using data sources for conditional references
data "aws_instance" "existing" {
  count = var.use_existing_instance ? 1 : 0
  
  instance_id = var.existing_instance_id
}

locals {
  instance_id = var.use_existing_instance ? data.aws_instance.existing[0].id : aws_instance.new[0].id
}
```

