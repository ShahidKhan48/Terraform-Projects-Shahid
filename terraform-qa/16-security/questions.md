# Terraform Security - Q&A

## Basic Questions

### Q1: What are the main security concerns with Terraform?
**Answer:** 
- **State file security**: Contains sensitive data in plain text
- **Credential management**: Storing and accessing cloud provider credentials
- **Secret management**: Handling passwords, API keys, and certificates
- **Access control**: Who can run Terraform and modify infrastructure
- **Network security**: Securing communication between Terraform and providers
- **Code security**: Protecting Terraform configurations from unauthorized access

### Q2: How do you secure Terraform state files?
**Answer:** 
- Use remote state backends (S3, Azure Storage, GCS)
- Enable encryption at rest and in transit
- Implement proper access controls (IAM policies)
- Use state locking to prevent concurrent modifications
- Never commit state files to version control
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### Q3: What are sensitive variables and how do you use them?
**Answer:** Sensitive variables prevent values from being displayed in logs and console output:
```hcl
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# Sensitive outputs
output "db_endpoint" {
  value     = aws_db_instance.main.endpoint
  sensitive = true
}

# Mark local values as sensitive
locals {
  api_key = sensitive(var.api_key)
}
```

## Intermediate Questions

### Q4: How do you manage credentials securely in Terraform?
**Answer:** 
```hcl
# Use environment variables
# export AWS_ACCESS_KEY_ID="your-access-key"
# export AWS_SECRET_ACCESS_KEY="your-secret-key"

# Use IAM roles (recommended)
provider "aws" {
  assume_role {
    role_arn = "arn:aws:iam::123456789012:role/TerraformRole"
  }
}

# Use credential files
provider "aws" {
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "terraform"
}

# Use external credential providers
provider "aws" {
  # Credentials from external process
}
```

### Q5: How do you implement least privilege access?
**Answer:** 
```hcl
# IAM policy for Terraform execution
data "aws_iam_policy_document" "terraform_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:CreateTags"
    ]
    resources = ["*"]
    
    condition {
      test     = "StringEquals"
      variable = "ec2:Region"
      values   = ["us-east-1", "us-west-2"]
    }
  }
  
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = ["arn:aws:s3:::terraform-state-bucket/*"]
  }
}

resource "aws_iam_policy" "terraform_policy" {
  name   = "TerraformExecutionPolicy"
  policy = data.aws_iam_policy_document.terraform_policy.json
}
```

### Q6: How do you use external secret management systems?
**Answer:** 
```hcl
# AWS Secrets Manager
data "aws_secretsmanager_secret" "db_password" {
  name = "prod/database/password"
}

data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = data.aws_secretsmanager_secret.db_password.id
}

resource "aws_db_instance" "main" {
  engine   = "mysql"
  username = "admin"
  password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]
}

# HashiCorp Vault
data "vault_generic_secret" "db_creds" {
  path = "secret/database"
}

resource "aws_db_instance" "main" {
  engine   = "mysql"
  username = data.vault_generic_secret.db_creds.data["username"]
  password = data.vault_generic_secret.db_creds.data["password"]
}
```

### Q7: How do you implement network security in Terraform?
**Answer:** 
```hcl
# Security Groups with least privilege
resource "aws_security_group" "web" {
  name_prefix = "web-"
  vpc_id      = aws_vpc.main.id
  
  # Only allow necessary ports
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Restrict SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]  # Internal only
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# NACLs for additional security
resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.main.id
  
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.0.0/16"
    from_port  = 80
    to_port    = 80
  }
  
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
}
```

## Advanced Questions

### Q8: How do you implement encryption in Terraform?
**Answer:** 
```hcl
# S3 bucket encryption
resource "aws_s3_bucket" "secure" {
  bucket = "my-secure-bucket"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure" {
  bucket = aws_s3_bucket.secure.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

# EBS encryption
resource "aws_ebs_volume" "secure" {
  availability_zone = "us-east-1a"
  size              = 20
  encrypted         = true
  kms_key_id        = aws_kms_key.ebs.arn
}

# RDS encryption
resource "aws_db_instance" "secure" {
  engine               = "mysql"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_encrypted    = true
  kms_key_id          = aws_kms_key.rds.arn
}
```

### Q9: How do you implement secure CI/CD with Terraform?
**Answer:** 
```yaml
# GitHub Actions example
name: Terraform Security
on:
  pull_request:
    branches: [main]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      # Security scanning
      - name: Run Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: .
          framework: terraform
          
      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          working_directory: .
          
      # Terraform operations with OIDC
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1
          
      - name: Terraform Plan
        run: |
          terraform init
          terraform plan -out=tfplan
          
      # Store plan securely
      - name: Upload plan
        uses: actions/upload-artifact@v3
        with:
          name: terraform-plan
          path: tfplan
          retention-days: 1
```

### Q10: What are Terraform security scanning tools?
**Answer:** 
- **tfsec**: Static analysis for Terraform code
- **Checkov**: Policy-as-code security scanning
- **Terrascan**: Static code analyzer
- **Snyk**: Vulnerability scanning
- **Bridgecrew**: Cloud security posture management
- **Sentinel**: Policy-as-code framework (Terraform Enterprise)

```bash
# tfsec example
tfsec .

# Checkov example
checkov -d . --framework terraform

# Terrascan example
terrascan scan -t terraform
```

### Q11: How do you implement policy-as-code with Terraform?
**Answer:** 
```hcl
# Using Sentinel (Terraform Enterprise)
# sentinel.hcl
policy "require-encryption" {
  source = "./require-encryption.sentinel"
  enforcement_level = "hard-mandatory"
}

# require-encryption.sentinel
import "tfplan/v2" as tfplan

require_s3_encryption = rule {
  all tfplan.resource_changes as _, rc {
    rc.type is "aws_s3_bucket_server_side_encryption_configuration" or
    rc.mode is "data"
  }
}

main = rule {
  require_s3_encryption
}
```

### Q12: How do you secure Terraform modules?
**Answer:** 
```hcl
# Module with security validations
variable "enable_encryption" {
  description = "Enable encryption for all resources"
  type        = bool
  default     = true
  
  validation {
    condition     = var.enable_encryption == true
    error_message = "Encryption must be enabled for security compliance."
  }
}

variable "allowed_cidr_blocks" {
  description = "Allowed CIDR blocks for security group rules"
  type        = list(string)
  
  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks :
      can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid."
  }
  
  validation {
    condition = !contains(var.allowed_cidr_blocks, "0.0.0.0/0")
    error_message = "Open access (0.0.0.0/0) is not allowed."
  }
}
```

### Q13: What are Terraform security best practices?
**Answer:** 
- Use remote state with encryption and access controls
- Implement least privilege access for Terraform execution
- Use sensitive variables for secrets
- Integrate security scanning in CI/CD pipelines
- Regularly rotate credentials and API keys
- Use policy-as-code for compliance enforcement
- Enable detailed logging and monitoring
- Use private module registries
- Implement proper secret management
- Regular security audits and reviews

### Q14: How do you handle compliance requirements?
**Answer:** 
```hcl
# Compliance tags
locals {
  compliance_tags = {
    Compliance     = "SOC2"
    DataClass      = "Confidential"
    Owner          = "security-team"
    CostCenter     = "12345"
    Environment    = var.environment
    BackupRequired = "true"
  }
}

# Enforce compliance through validation
variable "environment" {
  type = string
  
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# Compliance-required resources
resource "aws_cloudtrail" "compliance" {
  name           = "${var.project}-compliance-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail.bucket
  
  enable_logging                = true
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_log_file_validation   = true
  
  tags = local.compliance_tags
}
```

### Q15: How do you implement disaster recovery security?
**Answer:** 
```hcl
# Cross-region backup with encryption
resource "aws_s3_bucket_replication_configuration" "disaster_recovery" {
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.source.id
  
  rule {
    id     = "disaster-recovery"
    status = "Enabled"
    
    destination {
      bucket        = aws_s3_bucket.destination.arn
      storage_class = "STANDARD_IA"
      
      encryption_configuration {
        replica_kms_key_id = aws_kms_key.destination.arn
      }
    }
  }
}

# Automated backup with retention
resource "aws_backup_plan" "disaster_recovery" {
  name = "disaster-recovery-plan"
  
  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 ? * * *)"
    
    lifecycle {
      cold_storage_after = 30
      delete_after       = 120
    }
    
    recovery_point_tags = {
      Environment = var.environment
      Compliance  = "Required"
    }
  }
}
```

