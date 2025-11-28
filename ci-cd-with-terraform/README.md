# CI/CD with Terraform

## 🚀 Automated Infrastructure Deployment

This directory contains CI/CD pipeline configurations and scripts for automating Terraform deployments across different platforms.

## 📁 Directory Structure

### **GitHub Actions** 🐙
**Folder:** `github-actions/`
- Terraform plan and apply workflows
- Multi-environment deployments
- Security scanning and compliance
- Cost estimation integration
- Drift detection automation

### **Jenkins** 🔧
**Folder:** `jenkins/`
- Jenkinsfile for Terraform pipelines
- Shared library functions
- Multi-branch deployment strategies
- Approval gates and notifications
- Integration with external tools

### **Scripts & Utilities** 📜
**Folder:** `scripts/`
- Terraform wrapper scripts
- Environment setup automation
- State management utilities
- Security and compliance checks
- Cost optimization tools

## 🎯 Key Features

### **Automated Workflows**
- ✅ **Plan on PR**: Automatic terraform plan on pull requests
- ✅ **Apply on Merge**: Deploy infrastructure on main branch merge
- ✅ **Multi-Environment**: Dev, staging, production deployments
- ✅ **Drift Detection**: Scheduled checks for infrastructure drift
- ✅ **Cost Estimation**: Automatic cost impact analysis

### **Security & Compliance**
- ✅ **Security Scanning**: Checkov, tfsec integration
- ✅ **Policy Validation**: OPA/Sentinel policy checks
- ✅ **Secret Management**: Secure handling of credentials
- ✅ **Audit Logging**: Complete deployment audit trail
- ✅ **Approval Gates**: Manual approval for production

### **Quality Assurance**
- ✅ **Code Formatting**: Terraform fmt validation
- ✅ **Linting**: TFLint integration
- ✅ **Testing**: Terratest integration
- ✅ **Documentation**: Auto-generated docs
- ✅ **Notifications**: Slack/Teams integration

## 🔄 Workflow Examples

### **GitHub Actions Workflow**
```yaml
name: 'Terraform CI/CD'

on:
  pull_request:
    branches: [ main ]
  push:
    branches: [ main ]

jobs:
  terraform:
    name: 'Terraform'
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout
      uses: actions/checkout@v3
      
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: 1.5.0
        
    - name: Terraform Init
      run: terraform init
      
    - name: Terraform Plan
      run: terraform plan -no-color
      
    - name: Terraform Apply
      if: github.ref == 'refs/heads/main'
      run: terraform apply -auto-approve
```

### **Jenkins Pipeline**
```groovy
pipeline {
    agent any
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Target environment'
        )
        booleanParam(
            name: 'DESTROY',
            defaultValue: false,
            description: 'Destroy infrastructure'
        )
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Terraform Init') {
            steps {
                sh 'terraform init'
            }
        }
        
        stage('Terraform Plan') {
            steps {
                sh 'terraform plan -var-file=${ENVIRONMENT}.tfvars'
            }
        }
        
        stage('Approval') {
            when {
                expression { params.ENVIRONMENT == 'prod' }
            }
            steps {
                input message: 'Deploy to production?'
            }
        }
        
        stage('Terraform Apply') {
            when {
                not { params.DESTROY }
            }
            steps {
                sh 'terraform apply -var-file=${ENVIRONMENT}.tfvars -auto-approve'
            }
        }
        
        stage('Terraform Destroy') {
            when {
                expression { params.DESTROY }
            }
            steps {
                sh 'terraform destroy -var-file=${ENVIRONMENT}.tfvars -auto-approve'
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: '*.tfplan', allowEmptyArchive: true
        }
        success {
            slackSend color: 'good', message: "Terraform deployment successful for ${params.ENVIRONMENT}"
        }
        failure {
            slackSend color: 'danger', message: "Terraform deployment failed for ${params.ENVIRONMENT}"
        }
    }
}
```

## 🛠️ Setup Instructions

### **GitHub Actions Setup**
1. Copy workflows to `.github/workflows/`
2. Configure repository secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `TERRAFORM_CLOUD_TOKEN` (if using Terraform Cloud)
3. Update environment variables in workflow files
4. Enable branch protection rules

### **Jenkins Setup**
1. Install required plugins:
   - Terraform Plugin
   - AWS Steps Plugin
   - Slack Notification Plugin
2. Configure global credentials
3. Create multibranch pipeline
4. Set up webhook for automatic triggers

### **Prerequisites**
```bash
# Required tools
terraform --version  # >= 1.0
aws --version        # >= 2.0
git --version        # >= 2.0

# Optional tools
tflint --version     # Linting
checkov --version    # Security scanning
infracost --version  # Cost estimation
```

## 📋 Pipeline Strategies

### **GitFlow Strategy**
```
main branch     → Production deployment
develop branch  → Staging deployment
feature/* branches → Development deployment
```

### **Environment Promotion**
```
Development → Staging → Production
    ↓           ↓          ↓
Auto-deploy  Auto-deploy Manual approval
```

### **Blue-Green Deployment**
```yaml
# Blue environment (current)
terraform workspace select blue
terraform apply

# Green environment (new)
terraform workspace select green
terraform apply

# Switch traffic
# Destroy old environment
```

## 🔐 Security Best Practices

### **Secret Management**
- Use CI/CD platform secret stores
- Rotate credentials regularly
- Implement least privilege access
- Audit secret usage

### **State Security**
- Use remote state with encryption
- Implement state locking
- Restrict state file access
- Regular state backups

### **Code Security**
- Scan for hardcoded secrets
- Validate Terraform configurations
- Implement policy as code
- Regular security updates

## 📊 Monitoring & Observability

### **Pipeline Metrics**
- Deployment frequency
- Lead time for changes
- Mean time to recovery
- Change failure rate

### **Infrastructure Monitoring**
- Resource drift detection
- Cost tracking and alerts
- Performance monitoring
- Security compliance

### **Alerting**
```yaml
# Example Slack notification
- name: Notify Slack
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    channel: '#infrastructure'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## 🧪 Testing Strategies

### **Unit Testing**
```go
// Terratest example
func TestTerraformAWSExample(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../examples/aws",
        Vars: map[string]interface{}{
            "instance_type": "t3.micro",
        },
    }
    
    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)
    
    instanceId := terraform.Output(t, terraformOptions, "instance_id")
    assert.NotEmpty(t, instanceId)
}
```

### **Integration Testing**
- Deploy to test environment
- Run application tests
- Validate infrastructure state
- Clean up resources

### **Security Testing**
```bash
# Security scanning
checkov -f main.tf
tfsec .
terrascan scan -t aws
```

## 💰 Cost Management

### **Cost Estimation**
```yaml
- name: Infracost
  uses: infracost/infracost-gh-action@v0.16
  with:
    api-key: ${{ secrets.INFRACOST_API_KEY }}
    path: .
    terraform_plan_flags: -var-file=prod.tfvars
```

### **Cost Optimization**
- Right-size resources based on usage
- Implement auto-scaling
- Use spot instances where appropriate
- Regular cost reviews

## 🚀 Advanced Patterns

### **Multi-Cloud Deployment**
```yaml
strategy:
  matrix:
    provider: [aws, azure, gcp]
    environment: [dev, staging, prod]
```

### **Canary Deployments**
```hcl
# Deploy to subset of infrastructure
resource "aws_instance" "canary" {
  count = var.canary_enabled ? 1 : 0
  # ... configuration
}
```

### **Feature Flags**
```hcl
variable "enable_monitoring" {
  description = "Enable monitoring resources"
  type        = bool
  default     = false
}

resource "aws_cloudwatch_dashboard" "main" {
  count = var.enable_monitoring ? 1 : 0
  # ... configuration
}
```

## 📚 Additional Resources

### **Documentation**
- [Terraform Cloud/Enterprise](https://www.terraform.io/cloud)
- [GitHub Actions for Terraform](https://learn.hashicorp.com/tutorials/terraform/github-actions)
- [Jenkins with Terraform](https://plugins.jenkins.io/terraform/)

### **Tools & Integrations**
- [Atlantis](https://www.runatlantis.io/) - Terraform pull request automation
- [Terragrunt](https://terragrunt.gruntwork.io/) - Terraform wrapper
- [Spacelift](https://spacelift.io/) - Infrastructure delivery platform
- [env0](https://www.env0.com/) - Infrastructure automation platform

---

**Automate Everything! 🤖**

*Remember: Good CI/CD practices make infrastructure management safer, faster, and more reliable.*