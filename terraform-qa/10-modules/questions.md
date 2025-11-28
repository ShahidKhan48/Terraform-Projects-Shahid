# Terraform Modules - Q&A

## Basic Questions

### Q1: What are Terraform modules?
**Answer:** Terraform modules are containers for multiple resources that are used together. A module consists of a collection of .tf files kept together in a directory. Modules are the main way to package and reuse resource configurations with Terraform.

### Q2: What are the key components of a module?
**Answer:** 
- **Input variables** (variables.tf) - Parameters that customize the module
- **Output values** (outputs.tf) - Return values from the module
- **Resources** (main.tf) - The actual infrastructure components
- **Data sources** - External data the module needs
- **Local values** - Computed values within the module

### Q3: What is the difference between root module and child module?
**Answer:** 
- **Root module** - The working directory where you run terraform commands
- **Child module** - A module called by another module (including the root module)

## Intermediate Questions

### Q4: How do you call a module in Terraform?
**Answer:** 
```hcl
module "vpc" {
  source = "./modules/vpc"
  
  cidr_block = "10.0.0.0/16"
  environment = "production"
}
```

### Q5: What are the different module sources supported?
**Answer:** 
- Local paths: `./modules/vpc`
- Terraform Registry: `terraform-aws-modules/vpc/aws`
- GitHub: `github.com/user/repo//modules/vpc`
- Git: `git::https://example.com/vpc.git`
- HTTP URLs: `https://example.com/vpc.zip`
- S3 buckets: `s3::https://s3-eu-west-1.amazonaws.com/bucket/vpc.zip`

### Q6: How do you version modules?
**Answer:** 
```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"
}
```
Version constraints: `=`, `!=`, `>`, `<`, `>=`, `<=`, `~>`

### Q7: How do you pass data between modules?
**Answer:** 
- Use module outputs as inputs to other modules
- Use data sources to fetch information
- Use remote state data sources
```hcl
module "network" {
  source = "./modules/network"
}

module "compute" {
  source = "./modules/compute"
  vpc_id = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids
}
```

## Advanced Questions

### Q8: What are module best practices?
**Answer:** 
- Use semantic versioning for modules
- Keep modules focused and single-purpose
- Use consistent naming conventions
- Document inputs and outputs
- Include examples and README
- Use validation rules for variables
- Avoid hardcoded values
- Use locals for computed values

### Q9: How do you handle module dependencies?
**Answer:** 
- Use `depends_on` for explicit dependencies
- Use module outputs as inputs for implicit dependencies
- Terraform automatically handles dependency ordering
```hcl
module "database" {
  source = "./modules/database"
  depends_on = [module.network]
}
```

### Q10: What is module composition?
**Answer:** Module composition is the practice of building complex infrastructure by combining multiple smaller, focused modules. This promotes reusability and maintainability.

### Q11: How do you test Terraform modules?
**Answer:** 
- Use Terratest for automated testing
- Create example configurations
- Use `terraform validate` and `terraform plan`
- Implement integration tests
- Use static analysis tools like tflint

### Q12: What are common module anti-patterns?
**Answer:** 
- Creating overly complex modules
- Hardcoding values instead of using variables
- Not using outputs effectively
- Poor module boundaries
- Not versioning modules
- Circular dependencies between modules

### Q13: How do you handle sensitive data in modules?
**Answer:** 
- Mark variables as sensitive
- Use external secret management systems
- Avoid logging sensitive values
```hcl
variable "db_password" {
  type = string
  sensitive = true
}
```

### Q14: What is the module registry?
**Answer:** The Terraform Registry is a public repository of Terraform modules. It provides:
- Verified modules from trusted publishers
- Community modules
- Documentation and examples
- Version management
- Usage analytics

### Q15: How do you create a private module registry?
**Answer:** 
- Use Terraform Cloud/Enterprise
- Host modules in private Git repositories
- Use module sources with authentication
- Implement proper access controls

