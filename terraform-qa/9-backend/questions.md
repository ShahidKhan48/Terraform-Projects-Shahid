# Backend Configuration - Q&A

## Basic Questions

### Q1: What is a Terraform backend and why is it important?
**Answer:** A Terraform backend determines where and how Terraform state is stored and accessed. It's crucial for team collaboration, state locking, and maintaining infrastructure consistency.

**Key purposes:**
- **State Storage**: Where the state file is kept (local vs remote)
- **State Locking**: Prevents concurrent modifications
- **State Sharing**: Enables team collaboration
- **State Security**: Encryption and access control
- **State Backup**: Automatic versioning and recovery

**Default behavior:**
- Without backend configuration, Terraform uses local backend
- State stored in `terraform.tfstate` file in current directory
- No locking mechanism (dangerous for teams)

### Q2: What's the difference between local and remote backends?
**Answer:**

**Local Backend:**
```hcl
# Default - no configuration needed
# State stored in terraform.tfstate locally
```

**Pros:**
- Simple setup
- Fast access
- No external dependencies

**Cons:**
- No team collaboration
- No state locking
- Risk of state loss
- No backup/versioning

**Remote Backend (S3 example):**
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

**Pros:**
- Team collaboration
- State locking
- Automatic backup
- Encryption support
- Version history

**Cons:**
- More complex setup
- External dependencies
- Potential network latency

### Q3: How do you configure an S3 backend with DynamoDB locking?
**Answer:**

**Step 1: Create S3 bucket and DynamoDB table**
```hcl
# backend-setup.tf (run this first)
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-company-terraform-state"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "terraform-state-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
  
  tags = {
    Name = "Terraform State Lock Table"
  }
}
```

**Step 2: Configure backend in main configuration**
```hcl
terraform {
  backend "s3" {
    bucket         = "my-company-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

**Step 3: Initialize with backend**
```bash
terraform init
```

### Q4: What are the different types of backends available?
**Answer:**

**Cloud Storage Backends:**
```hcl
# AWS S3
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "path/terraform.tfstate"
    region = "us-west-2"
  }
}

# Azure Storage
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-rg"
    storage_account_name = "terraformstate"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}

# Google Cloud Storage
terraform {
  backend "gcs" {
    bucket = "terraform-state-bucket"
    prefix = "terraform/state"
  }
}
```

**Terraform Cloud/Enterprise:**
```hcl
terraform {
  backend "remote" {
    organization = "my-org"
    
    workspaces {
      name = "production"
    }
  }
}
```

**Other Backends:**
```hcl
# Consul
terraform {
  backend "consul" {
    address = "consul.example.com"
    scheme  = "https"
    path    = "terraform/state"
  }
}

# HTTP Backend
terraform {
  backend "http" {
    address        = "https://mycompany.com/terraform_state/prod"
    lock_address   = "https://mycompany.com/terraform_lock/prod"
    unlock_address = "https://mycompany.com/terraform_lock/prod"
  }
}
```

### Q5: How do you migrate between backends?
**Answer:**

**Migration Process:**
```bash
# 1. Backup current state
terraform state pull > backup.tfstate

# 2. Update backend configuration
# Edit main.tf to change backend settings

# 3. Reinitialize with migration
terraform init -migrate-state

# 4. Verify migration
terraform state list
terraform plan  # Should show no changes
```

**Example Migration (Local to S3):**
```hcl
# Before (local backend)
# No backend configuration

# After (S3 backend)
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-west-2"
  }
}
```

**Migration Commands:**
```bash
# Interactive migration
terraform init

# Automatic migration (non-interactive)
terraform init -migrate-state -force-copy

# Reconfigure backend without migration
terraform init -reconfigure
```

## Intermediate Questions

### Q6: How do you handle backend configuration for multiple environments?
**Answer:**

**Approach 1: Different State Keys**
```hcl
# environments/dev/main.tf
terraform {
  backend "s3" {
    bucket = "company-terraform-state"
    key    = "dev/terraform.tfstate"
    region = "us-west-2"
  }
}

# environments/staging/main.tf
terraform {
  backend "s3" {
    bucket = "company-terraform-state"
    key    = "staging/terraform.tfstate"
    region = "us-west-2"
  }
}

# environments/prod/main.tf
terraform {
  backend "s3" {
    bucket = "company-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-west-2"
  }
}
```

**Approach 2: Partial Backend Configuration**
```hcl
# main.tf (same for all environments)
terraform {
  backend "s3" {
    # Partial configuration - values provided during init
  }
}
```

**Backend config files:**
```hcl
# config/dev.hcl
bucket = "company-terraform-state"
key    = "dev/terraform.tfstate"
region = "us-west-2"

# config/prod.hcl
bucket = "company-terraform-state"
key    = "prod/terraform.tfstate"
region = "us-west-2"
```

**Usage:**
```bash
# Initialize for different environments
terraform init -backend-config=config/dev.hcl
terraform init -backend-config=config/prod.hcl
```

**Approach 3: Terraform Workspaces**
```hcl
terraform {
  backend "s3" {
    bucket = "company-terraform-state"
    key    = "workspaces/terraform.tfstate"
    region = "us-west-2"
  }
}
```

```bash
# Create and use workspaces
terraform workspace new dev
terraform workspace new prod
terraform workspace select dev
```

### Q7: How do you implement backend authentication and security?
**Answer:**

**AWS S3 Backend Security:**
```hcl
terraform {
  backend "s3" {
    bucket         = "secure-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true                    # Server-side encryption
    kms_key_id     = "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
    dynamodb_table = "terraform-state-lock"
    
    # Optional: Assume role for cross-account access
    role_arn = "arn:aws:iam::123456789012:role/TerraformStateRole"
  }
}
```

**IAM Policy for S3 Backend:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::secure-terraform-state/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::secure-terraform-state"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:us-west-2:123456789012:table/terraform-state-lock"
    }
  ]
}
```

**Azure Backend Security:**
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-rg"
    storage_account_name = "terraformstate"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
    
    # Authentication options
    use_azuread_auth = true
    # Or use SAS token, access key, etc.
  }
}
```

**Environment Variables for Authentication:**
```bash
# AWS
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-west-2"

# Azure
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

# Google Cloud
export GOOGLE_CREDENTIALS="path/to/service-account.json"
```

### Q8: How do you handle state locking and resolve lock conflicts?
**Answer:**

**Understanding State Locking:**
```bash
# When Terraform acquires a lock
terraform plan    # Acquires read lock
terraform apply   # Acquires write lock
terraform destroy # Acquires write lock
```

**Lock Information:**
```bash
# Check current lock status
terraform force-unlock -help

# View lock details (if supported by backend)
aws dynamodb get-item \
  --table-name terraform-state-lock \
  --key '{"LockID":{"S":"my-bucket/prod/terraform.tfstate-md5"}}'
```

**Resolving Lock Conflicts:**

**1. Wait for lock to release naturally:**
```bash
# Lock will auto-release when operation completes
# Check if another team member is running Terraform
```

**2. Force unlock (use carefully):**
```bash
# Get lock ID from error message
terraform force-unlock <LOCK_ID>

# Example
terraform force-unlock 1234567890abcdef1234567890abcdef
```

**3. Manual DynamoDB unlock (emergency):**
```bash
# Delete lock item from DynamoDB
aws dynamodb delete-item \
  --table-name terraform-state-lock \
  --key '{"LockID":{"S":"<LOCK_ID>"}}'
```

**Preventing Lock Issues:**
```bash
# Use shorter timeout for operations
terraform apply -lock-timeout=10m

# Disable locking (not recommended)
terraform apply -lock=false
```

**Lock Troubleshooting:**
```bash
# Check who has the lock
aws dynamodb scan --table-name terraform-state-lock

# Verify lock table exists
aws dynamodb describe-table --table-name terraform-state-lock
```

### Q9: How do you implement backend versioning and backup strategies?
**Answer:**

**S3 Backend Versioning:**
```hcl
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    id     = "state_lifecycle"
    status = "Enabled"
    
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
  }
}
```

**Manual Backup Strategies:**
```bash
# Regular state backup
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
terraform state pull > "backups/terraform.tfstate.${DATE}"

# Automated backup script
#!/bin/bash
BACKUP_DIR="state-backups"
mkdir -p $BACKUP_DIR

# Pull current state
terraform state pull > "${BACKUP_DIR}/terraform.tfstate.$(date +%Y%m%d_%H%M%S)"

# Keep only last 30 backups
ls -t ${BACKUP_DIR}/terraform.tfstate.* | tail -n +31 | xargs rm -f
```

**Cross-Region Replication:**
```hcl
resource "aws_s3_bucket_replication_configuration" "terraform_state" {
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    id     = "replicate_state"
    status = "Enabled"
    
    destination {
      bucket        = aws_s3_bucket.terraform_state_replica.arn
      storage_class = "STANDARD_IA"
    }
  }
}
```

**State Recovery Process:**
```bash
# List available versions
aws s3api list-object-versions \
  --bucket my-terraform-state \
  --prefix prod/terraform.tfstate

# Restore specific version
aws s3api get-object \
  --bucket my-terraform-state \
  --key prod/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.restored

# Verify restored state
terraform state list -state=terraform.tfstate.restored
```

### Q10: How do you share state data between Terraform configurations?
**Answer:**

**Using terraform_remote_state Data Source:**
```hcl
# Infrastructure stack (outputs VPC info)
# infrastructure/main.tf
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

# Application stack (consumes VPC info)
# application/main.tf
data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  
  config = {
    bucket = "company-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "us-west-2"
  }
}

resource "aws_instance" "app" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  subnet_id     = data.terraform_remote_state.infrastructure.outputs.private_subnet_ids[0]
  
  vpc_security_group_ids = [aws_security_group.app.id]
}

resource "aws_security_group" "app" {
  vpc_id = data.terraform_remote_state.infrastructure.outputs.vpc_id
  
  # ... security group rules
}
```

**Cross-Account State Sharing:**
```hcl
data "terraform_remote_state" "shared_services" {
  backend = "s3"
  
  config = {
    bucket   = "shared-services-terraform-state"
    key      = "networking/terraform.tfstate"
    region   = "us-west-2"
    role_arn = "arn:aws:iam::123456789012:role/CrossAccountTerraformRole"
  }
}
```

**Alternative: Using Data Sources:**
```hcl
# Instead of remote state, use data sources
data "aws_vpc" "shared" {
  filter {
    name   = "tag:Name"
    values = ["shared-vpc"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.shared.id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}

resource "aws_instance" "app" {
  subnet_id = data.aws_subnets.private.ids[0]
  # ... other configuration
}
```

## Advanced Questions

### Q11: How do you implement custom backends or HTTP backends?
**Answer:**

**HTTP Backend Configuration:**
```hcl
terraform {
  backend "http" {
    address        = "https://api.mycompany.com/terraform/state/prod"
    lock_address   = "https://api.mycompany.com/terraform/lock/prod"
    unlock_address = "https://api.mycompany.com/terraform/lock/prod"
    username       = "terraform-user"
    password       = "secure-password"
    
    # Optional: Custom headers
    retry_max = 3
    retry_wait_min = 1
    retry_wait_max = 30
  }
}
```

**HTTP Backend Server Implementation (Go example):**
```go
package main

import (
    "encoding/json"
    "io/ioutil"
    "net/http"
    "sync"
)

type StateServer struct {
    states map[string][]byte
    locks  map[string]string
    mutex  sync.RWMutex
}

func (s *StateServer) handleState(w http.ResponseWriter, r *http.Request) {
    path := r.URL.Path
    
    switch r.Method {
    case "GET":
        s.mutex.RLock()
        state, exists := s.states[path]
        s.mutex.RUnlock()
        
        if !exists {
            http.NotFound(w, r)
            return
        }
        
        w.Header().Set("Content-Type", "application/json")
        w.Write(state)
        
    case "POST":
        body, err := ioutil.ReadAll(r.Body)
        if err != nil {
            http.Error(w, err.Error(), http.StatusBadRequest)
            return
        }
        
        s.mutex.Lock()
        s.states[path] = body
        s.mutex.Unlock()
        
        w.WriteHeader(http.StatusOK)
    }
}

func (s *StateServer) handleLock(w http.ResponseWriter, r *http.Request) {
    path := r.URL.Path
    
    switch r.Method {
    case "LOCK":
        // Implement locking logic
        s.mutex.Lock()
        if _, locked := s.locks[path]; locked {
            s.mutex.Unlock()
            http.Error(w, "State is locked", http.StatusConflict)
            return
        }
        s.locks[path] = "locked"
        s.mutex.Unlock()
        
    case "UNLOCK":
        // Implement unlocking logic
        s.mutex.Lock()
        delete(s.locks, path)
        s.mutex.Unlock()
    }
}
```

**Custom Backend Plugin (Advanced):**
```go
// Custom backend plugin structure
type Backend struct {
    // Backend configuration
    config *Config
}

func (b *Backend) Configure(ctx context.Context) error {
    // Initialize backend connection
    return nil
}

func (b *Backend) StateMgr(name string) (statemgr.Full, error) {
    // Return state manager implementation
    return &StateManager{
        backend: b,
        name:    name,
    }, nil
}
```

### Q12: How do you handle backend performance optimization?
**Answer:**

**S3 Backend Optimization:**
```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-west-2"
    
    # Performance optimizations
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    
    # Use regional endpoint for better performance
    endpoint = "https://s3.us-west-2.amazonaws.com"
  }
}
```

**State Size Optimization:**
```bash
# Check state file size
terraform state pull | wc -c

# Identify large resources in state
terraform state list | while read resource; do
  echo "Resource: $resource"
  terraform state show "$resource" | wc -c
done | sort -k2 -n
```

**State Splitting for Performance:**
```hcl
# Split large configurations into smaller stacks
# networking/main.tf - Network resources only
# compute/main.tf - Compute resources only
# database/main.tf - Database resources only

# Use remote state to share data between stacks
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "terraform-state"
    key    = "networking/terraform.tfstate"
    region = "us-west-2"
  }
}
```

**Parallel State Operations:**
```bash
# Use parallelism for faster operations
terraform apply -parallelism=20

# Adjust based on backend capabilities and rate limits
terraform plan -parallelism=10
```

**Caching Strategies:**
```bash
# Use local caching for remote state
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"

# Pre-download providers
terraform providers lock -platform=linux_amd64 -platform=darwin_amd64
```

### Q13: What are backend security best practices?
**Answer:**

**Access Control:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::123456789012:role/TerraformRole",
          "arn:aws:iam::123456789012:user/terraform-ci"
        ]
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::terraform-state/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-server-side-encryption": "AES256"
        }
      }
    }
  ]
}
```

**Encryption at Rest:**
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 7
  
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
      }
    ]
  })
}
```

**Network Security:**
```hcl
# VPC Endpoint for S3 (private access)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-west-2.s3"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::terraform-state",
          "arn:aws:s3:::terraform-state/*"
        ]
      }
    ]
  })
}
```

**Audit and Monitoring:**
```hcl
# CloudTrail for state access logging
resource "aws_cloudtrail" "terraform_state" {
  name           = "terraform-state-audit"
  s3_bucket_name = aws_s3_bucket.audit_logs.bucket
  
  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    
    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.terraform_state.arn}/*"]
    }
  }
}

# CloudWatch alarms for unusual access
resource "aws_cloudwatch_metric_alarm" "state_access" {
  alarm_name          = "terraform-state-unusual-access"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NumberOfObjects"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors terraform state access"
  
  dimensions = {
    BucketName = aws_s3_bucket.terraform_state.bucket
  }
}
```

### Q14: How do you troubleshoot backend issues?
**Answer:**

**Common Backend Issues:**

**1. Backend Initialization Failures:**
```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform init

# Check backend configuration
terraform init -backend=false
terraform validate

# Reconfigure backend
terraform init -reconfigure
```

**2. State Lock Issues:**
```bash
# Check lock status
aws dynamodb get-item \
  --table-name terraform-state-lock \
  --key '{"LockID":{"S":"bucket/path/terraform.tfstate-md5"}}'

# Force unlock if needed
terraform force-unlock <LOCK_ID>

# Verify lock table configuration
aws dynamodb describe-table --table-name terraform-state-lock
```

**3. Permission Issues:**
```bash
# Test AWS credentials
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://terraform-state/

# Test DynamoDB access
aws dynamodb scan --table-name terraform-state-lock --max-items 1
```

**4. State Corruption:**
```bash
# Backup current state
terraform state pull > backup.tfstate

# Validate state file
terraform state list

# Restore from backup if needed
terraform state push backup.tfstate
```

**5. Backend Migration Issues:**
```bash
# Check migration status
terraform init -migrate-state

# Manual migration if needed
terraform state pull > old-state.tfstate
# Update backend configuration
terraform init
terraform state push old-state.tfstate
```

**Debugging Tools:**
```bash
# State inspection
terraform state show <resource>
terraform state list
terraform show

# Backend connectivity test
terraform init -backend-config="bucket=test-bucket"

# Validate configuration
terraform validate
terraform plan -detailed-exitcode
```

### Q15: What are enterprise backend patterns and best practices?
**Answer:**

**Multi-Account Backend Strategy:**
```hcl
# Centralized state management account
# Account: terraform-state (123456789012)
resource "aws_s3_bucket" "central_state" {
  bucket = "company-terraform-state-central"
}

# Cross-account access role
resource "aws_iam_role" "cross_account_terraform" {
  name = "CrossAccountTerraformRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::111111111111:root",  # Dev account
            "arn:aws:iam::222222222222:root",  # Prod account
          ]
        }
      }
    ]
  })
}
```

**Environment Isolation:**
```hcl
# Separate backends per environment
# dev/backend.tf
terraform {
  backend "s3" {
    bucket = "company-terraform-state"
    key    = "environments/dev/terraform.tfstate"
    region = "us-west-2"
  }
}

# prod/backend.tf
terraform {
  backend "s3" {
    bucket = "company-terraform-state-prod"  # Separate bucket for prod
    key    = "environments/prod/terraform.tfstate"
    region = "us-west-2"
  }
}
```

**Team-Based Access Control:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TeamAAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/TeamARole"
      },
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::terraform-state/team-a/*"
    },
    {
      "Sid": "TeamBAccess", 
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/TeamBRole"
      },
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::terraform-state/team-b/*"
    }
  ]
}
```

**Automated Backend Management:**
```bash
#!/bin/bash
# backend-setup.sh

ENVIRONMENT=$1
TEAM=$2

if [ -z "$ENVIRONMENT" ] || [ -z "$TEAM" ]; then
  echo "Usage: $0 <environment> <team>"
  exit 1
fi

# Create backend configuration
cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket = "company-terraform-state"
    key    = "${TEAM}/${ENVIRONMENT}/terraform.tfstate"
    region = "us-west-2"
    dynamodb_table = "terraform-state-lock"
    encrypt = true
  }
}
EOF

# Initialize backend
terraform init

echo "Backend configured for ${TEAM}/${ENVIRONMENT}"
```

**Compliance and Governance:**
```hcl
# Backend with compliance requirements
terraform {
  backend "s3" {
    bucket = "compliant-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-west-2"
    
    # Compliance requirements
    encrypt                     = true
    kms_key_id                 = "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
    dynamodb_table             = "terraform-state-lock"
    skip_credentials_validation = false
    skip_metadata_api_check     = false
    
    # Audit trail
    workspace_key_prefix = "workspaces"
  }
}
```