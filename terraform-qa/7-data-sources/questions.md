# Data Sources - Q&A

## Basic Questions

### Q1: What are Terraform data sources?
**Answer:** Data sources in Terraform allow you to fetch information about existing infrastructure or external systems that are not managed by the current Terraform configuration. They provide read-only access to data and are used to reference existing resources or retrieve dynamic information.

**Key characteristics:**
- Read-only operations
- Fetch existing infrastructure details
- Query external APIs or services
- Provide dynamic data to resources
- No state management (don't create/modify resources)

### Q2: What's the difference between resources and data sources?
**Answer:**
| Aspect | Resources | Data Sources |
|--------|-----------|--------------|
| **Purpose** | Create/manage infrastructure | Fetch existing information |
| **Operations** | Create, Read, Update, Delete | Read-only |
| **State** | Tracked in state file | Not tracked in state |
| **Syntax** | `resource "type" "name"` | `data "type" "name"` |
| **Lifecycle** | Managed by Terraform | External to Terraform |

### Q3: How do you define a data source in Terraform?
**Answer:**
```hcl
# Basic syntax
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Using the data source
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
}
```

### Q4: What are some common AWS data sources?
**Answer:**
```hcl
# AMI data source
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# VPC data source
data "aws_vpc" "default" {
  default = true
}

# Subnets data source
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Current caller identity
data "aws_caller_identity" "current" {}

# Current region
data "aws_region" "current" {}
```

### Q5: How do you filter data sources?
**Answer:**
```hcl
# Using filters
data "aws_ami" "web" {
  most_recent = true
  owners      = ["self", "amazon"]
  
  filter {
    name   = "name"
    values = ["myapp-*"]
  }
  
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Using tags
data "aws_instance" "web" {
  filter {
    name   = "tag:Environment"
    values = ["production"]
  }
  
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}
```

## Intermediate Questions

### Q6: How do you handle data source dependencies?
**Answer:**
```hcl
# Data sources can depend on resources
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "main-vpc"
  }
}

# This data source depends on the VPC resource
data "aws_subnets" "main" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.main.id]
  }
  
  depends_on = [aws_vpc.main]
}

# Using the data in another resource
resource "aws_instance" "web" {
  count           = length(data.aws_subnets.main.ids)
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t3.micro"
  subnet_id       = data.aws_subnets.main.ids[count.index]
}
```

### Q7: How do you use data sources for cross-stack references?
**Answer:**
```hcl
# Stack A (networking) - outputs VPC ID
output "vpc_id" {
  value = aws_vpc.main.id
}

# Stack B (compute) - uses data source to reference VPC
data "aws_vpc" "shared" {
  filter {
    name   = "tag:Name"
    values = ["shared-vpc"]
  }
}

# Alternative: using remote state data source
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "my-terraform-state"
    key    = "networking/terraform.tfstate"
    region = "us-west-2"
  }
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = data.terraform_remote_state.networking.outputs.private_subnet_id
}
```

### Q8: How do you handle data source errors and validation?
**Answer:**
```hcl
# Using validation
data "aws_ami" "app" {
  most_recent = true
  owners      = ["self"]
  
  filter {
    name   = "name"
    values = ["${var.app_name}-*"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Validate that AMI was found
locals {
  ami_id = data.aws_ami.app.id
}

# Use lifecycle to prevent errors
resource "aws_instance" "app" {
  ami           = local.ami_id
  instance_type = var.instance_type
  
  lifecycle {
    precondition {
      condition     = data.aws_ami.app.id != ""
      error_message = "No AMI found matching the criteria."
    }
  }
}

# Alternative: using try() function
locals {
  ami_id = try(data.aws_ami.app.id, var.default_ami_id)
}
```

### Q9: How do you use data sources with for_each?
**Answer:**
```hcl
# Get all subnets in a VPC
data "aws_subnets" "app" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  
  filter {
    name   = "tag:Tier"
    values = ["private"]
  }
}

# Convert to set for for_each
locals {
  subnet_ids = toset(data.aws_subnets.app.ids)
}

# Create security group rules for each subnet
resource "aws_security_group_rule" "app_access" {
  for_each = local.subnet_ids
  
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [data.aws_subnet.app[each.key].cidr_block]
  security_group_id = aws_security_group.app.id
}

# Get individual subnet details
data "aws_subnet" "app" {
  for_each = local.subnet_ids
  id       = each.value
}
```

### Q10: How do you use external data sources?
**Answer:**
```hcl
# External data source for custom scripts
data "external" "vault_token" {
  program = ["bash", "${path.module}/scripts/get-vault-token.sh"]
  
  query = {
    vault_addr = var.vault_address
    role_id    = var.vault_role_id
  }
}

# HTTP data source
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

# Template data source (deprecated, use templatefile() function)
data "template_file" "user_data" {
  template = file("${path.module}/templates/user-data.sh")
  
  vars = {
    app_name    = var.app_name
    environment = var.environment
  }
}

# Modern approach using templatefile()
locals {
  user_data = templatefile("${path.module}/templates/user-data.sh", {
    app_name    = var.app_name
    environment = var.environment
  })
}
```

## Advanced Questions

### Q11: How do you optimize data source performance?
**Answer:**
```hcl
# Use specific filters to reduce query time
data "aws_ami" "optimized" {
  most_recent = true
  owners      = ["099720109477"]
  
  # Specific filters reduce search space
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20230*"]
  }
  
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Cache data sources using locals
locals {
  # Compute once, use multiple times
  availability_zones = data.aws_availability_zones.available.names
  vpc_id            = data.aws_vpc.main.id
}

# Use depends_on to control execution order
data "aws_instances" "web" {
  depends_on = [aws_autoscaling_group.web]
  
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.web.name]
  }
}
```

### Q12: How do you handle data source pagination and limits?
**Answer:**
```hcl
# Some data sources return limited results
data "aws_instances" "all_web" {
  filter {
    name   = "tag:Environment"
    values = ["production"]
  }
  
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# Use multiple data sources for large datasets
data "aws_instances" "web_batch_1" {
  filter {
    name   = "tag:Batch"
    values = ["1"]
  }
}

data "aws_instances" "web_batch_2" {
  filter {
    name   = "tag:Batch"
    values = ["2"]
  }
}

locals {
  all_instances = concat(
    data.aws_instances.web_batch_1.ids,
    data.aws_instances.web_batch_2.ids
  )
}
```

### Q13: How do you implement conditional data sources?
**Answer:**
```hcl
# Conditional data source using count
data "aws_ami" "custom" {
  count       = var.use_custom_ami ? 1 : 0
  most_recent = true
  owners      = ["self"]
  
  filter {
    name   = "name"
    values = ["${var.app_name}-*"]
  }
}

# Use in resource with conditional logic
resource "aws_instance" "web" {
  ami = var.use_custom_ami ? data.aws_ami.custom[0].id : data.aws_ami.default.id
  instance_type = var.instance_type
}

# Alternative using try() function
locals {
  ami_id = var.use_custom_ami ? try(data.aws_ami.custom[0].id, data.aws_ami.default.id) : data.aws_ami.default.id
}
```

### Q14: How do you test and validate data sources?
**Answer:**
```hcl
# Add validation to ensure data source returns expected results
data "aws_ami" "app" {
  most_recent = true
  owners      = ["self"]
  
  filter {
    name   = "name"
    values = ["${var.app_name}-*"]
  }
}

# Validation block
variable "app_name" {
  type = string
  
  validation {
    condition     = length(var.app_name) > 0
    error_message = "App name cannot be empty."
  }
}

# Local validation
locals {
  validate_ami = data.aws_ami.app.id != "" ? data.aws_ami.app.id : file("ERROR: No AMI found")
}

# Output for debugging
output "debug_ami_info" {
  value = {
    ami_id      = data.aws_ami.app.id
    ami_name    = data.aws_ami.app.name
    owner_id    = data.aws_ami.app.owner_id
    creation_date = data.aws_ami.app.creation_date
  }
}
```

### Q15: What are best practices for data sources?
**Answer:**

**Performance Best Practices:**
- Use specific filters to reduce query scope
- Cache frequently used data in locals
- Avoid unnecessary data source calls
- Use depends_on when needed

**Security Best Practices:**
```hcl
# Don't expose sensitive data in outputs
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/password"
}

# Use sensitive = true for outputs
output "db_connection" {
  value = {
    host     = data.aws_db_instance.main.address
    port     = data.aws_db_instance.main.port
    username = data.aws_db_instance.main.username
  }
  sensitive = true
}
```

**Reliability Best Practices:**
```hcl
# Handle missing resources gracefully
data "aws_instance" "web" {
  count = var.existing_instance_id != "" ? 1 : 0
  
  instance_id = var.existing_instance_id
}

locals {
  instance_ip = length(data.aws_instance.web) > 0 ? data.aws_instance.web[0].private_ip : null
}
```

**Maintainability Best Practices:**
- Use descriptive names for data sources
- Add comments explaining complex filters
- Group related data sources together
- Document expected data source behavior