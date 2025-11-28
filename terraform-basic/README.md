# Terraform Basic Examples

## 🎯 Hands-on Learning Examples

This directory contains 16 practical Terraform examples designed for hands-on learning, from basic resource creation to advanced patterns.

## 📁 Directory Structure

### **Core AWS Services**
- **`aws-ec2/`** - Basic EC2 instance creation
- **`aws-s3/`** - S3 bucket management and policies  
- **`aws-vpc/`** - VPC networking fundamentals
- **`aws-vpc-ec2-nginx/`** - Complete VPC with EC2 and Nginx
- **`aws-IAM-management/`** - IAM users, roles, and policies

### **Terraform Fundamentals**
- **`tf-variables/`** - Input, local, and output variables
- **`tf-functions/`** - Built-in Terraform functions
- **`tf-data-sources/`** - Using data sources effectively
- **`tf-multi-resources/`** - Managing multiple resources
- **`tf-operators-exps/`** - Operators and expressions

### **Advanced Concepts**
- **`tf-backend/`** - Remote state configuration
- **`tf-cli-workspace/`** - Workspace management
- **`tf-module-vpc/`** - Basic module creation
- **`tf-own-module-VPC/`** - Custom VPC module development
- **`testing-local-module/`** - Local module testing

### **Projects**
- **`proj-static-website/`** - Static website hosting on S3
- **`tf-test/`** - Testing and validation examples

## 🚀 Quick Start Guide

### Prerequisites
```bash
# Install Terraform
terraform --version  # >= 1.0

# Configure AWS CLI
aws configure
aws sts get-caller-identity
```

### Running Examples
```bash
# Navigate to any example
cd aws-ec2

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply

# Clean up resources
terraform destroy
```

## 📋 Learning Path

### **Beginner (Start Here)**
1. **`aws-ec2/`** - Your first Terraform resource
2. **`tf-variables/`** - Learn variable management
3. **`aws-s3/`** - Storage and policies
4. **`tf-data-sources/`** - Fetching existing resources

### **Intermediate**
1. **`aws-vpc/`** - Networking basics
2. **`tf-multi-resources/`** - Resource dependencies
3. **`tf-functions/`** - Built-in functions
4. **`aws-vpc-ec2-nginx/`** - Complete infrastructure

### **Advanced**
1. **`tf-backend/`** - Remote state management
2. **`tf-module-vpc/`** - Module creation
3. **`tf-cli-workspace/`** - Environment management
4. **`tf-own-module-VPC/`** - Custom module development

## 💡 Key Learning Objectives

### **Basic Concepts**
- ✅ Terraform workflow (init, plan, apply, destroy)
- ✅ Resource creation and management
- ✅ Variable usage and validation
- ✅ Output values and references

### **Intermediate Skills**
- ✅ Data sources and external data
- ✅ Resource dependencies and ordering
- ✅ Built-in functions and expressions
- ✅ Multi-resource configurations

### **Advanced Patterns**
- ✅ Remote state and backends
- ✅ Workspace management
- ✅ Module creation and reuse
- ✅ Testing and validation

## 🔧 Example Highlights

### **AWS EC2 Instance**
```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t3.micro"
  
  tags = {
    Name = "HelloWorld"
  }
}
```

### **S3 Bucket with Policy**
```hcl
resource "aws_s3_bucket" "example" {
  bucket = "my-terraform-bucket-${random_string.suffix.result}"
}

resource "aws_s3_bucket_policy" "example" {
  bucket = aws_s3_bucket.example.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.example.arn}/*"
      }
    ]
  })
}
```

### **VPC with Subnets**
```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "public-subnet"
  }
}
```

## 📊 Complexity Matrix

| Example | Resources | Difficulty | Time | Focus Area |
|---------|-----------|------------|------|------------|
| **aws-ec2** | 1-2 | ⭐ | 5 min | Basic resources |
| **aws-s3** | 2-3 | ⭐ | 10 min | Storage & policies |
| **tf-variables** | 3-5 | ⭐⭐ | 15 min | Variable management |
| **aws-vpc** | 5-8 | ⭐⭐ | 20 min | Networking basics |
| **tf-data-sources** | 3-4 | ⭐⭐ | 15 min | External data |
| **tf-functions** | 2-3 | ⭐⭐ | 20 min | Built-in functions |
| **aws-vpc-ec2-nginx** | 10-15 | ⭐⭐⭐ | 30 min | Complete setup |
| **tf-backend** | 2-3 | ⭐⭐⭐ | 25 min | State management |
| **tf-module-vpc** | 8-10 | ⭐⭐⭐ | 35 min | Module basics |
| **tf-own-module-VPC** | 15-20 | ⭐⭐⭐⭐ | 45 min | Custom modules |

## 🛠️ Common Patterns

### **Variable Definition**
```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
  
  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "Instance type must be t3.micro, t3.small, or t3.medium."
  }
}
```

### **Local Values**
```hcl
locals {
  common_tags = {
    Environment = "development"
    Project     = "terraform-learning"
    ManagedBy   = "terraform"
  }
  
  instance_name = "${var.project_name}-${var.environment}-web"
}
```

### **Output Values**
```hcl
output "instance_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}
```

## 🔍 Troubleshooting Tips

### **Common Issues**
1. **Provider not configured**: Run `aws configure`
2. **Resource already exists**: Use `terraform import`
3. **Permission denied**: Check IAM policies
4. **State lock**: Use `terraform force-unlock`

### **Best Practices**
- Always run `terraform plan` before `apply`
- Use meaningful resource names and tags
- Keep configurations simple and readable
- Version control your Terraform files
- Use variables for reusable values

## 📚 Next Steps

After completing these examples:

1. **Move to Projects**: Try `../terraform-projects/` for production-ready infrastructure
2. **Learn Concepts**: Study `../terraform-concepts/` for deeper understanding
3. **Practice Q&A**: Test knowledge with `../terraform-qa/`
4. **Build Custom**: Create your own infrastructure projects

## 🤝 Contributing

To add new examples:
1. Create a new directory with descriptive name
2. Include main.tf, variables.tf, outputs.tf
3. Add comprehensive README.md
4. Test thoroughly before committing
5. Update this main README.md

---

**Happy Learning! 🚀**

*Start with simple examples and gradually work your way up to more complex configurations.*