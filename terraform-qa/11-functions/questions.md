# Terraform Functions - Q&A

## Basic Questions

### Q1: What are Terraform functions?
**Answer:** Terraform functions are built-in operations that transform and combine values. They are used within expressions to manipulate data, perform calculations, and format output.

### Q2: What are the main categories of Terraform functions?
**Answer:** 
- **Numeric functions** - Mathematical operations
- **String functions** - Text manipulation
- **Collection functions** - List, map, and set operations
- **Encoding functions** - Data encoding/decoding
- **Filesystem functions** - File operations
- **Date/Time functions** - Time manipulation
- **Hash/Crypto functions** - Cryptographic operations
- **IP Network functions** - Network calculations
- **Type conversion functions** - Data type conversions

### Q3: How do you call a function in Terraform?
**Answer:** Functions are called using the syntax `function_name(argument1, argument2, ...)`
```hcl
locals {
  upper_name = upper(var.name)
  subnet_cidr = cidrsubnet("10.0.0.0/16", 8, 1)
}
```

## Intermediate Questions

### Q4: What are commonly used string functions?
**Answer:** 
- `upper()` / `lower()` - Change case
- `length()` - Get string length
- `substr()` - Extract substring
- `replace()` - Replace text
- `split()` / `join()` - Split/join strings
- `trim()` - Remove whitespace
- `format()` - Format strings
```hcl
locals {
  name = upper(var.environment)
  tags = split(",", var.tag_list)
  message = format("Hello %s!", var.username)
}
```

### Q5: What are useful collection functions?
**Answer:** 
- `length()` - Get collection size
- `element()` - Get element by index
- `contains()` - Check if value exists
- `keys()` / `values()` - Get map keys/values
- `merge()` - Merge maps
- `concat()` - Concatenate lists
- `distinct()` - Remove duplicates
- `sort()` - Sort collection
```hcl
locals {
  all_subnets = concat(var.public_subnets, var.private_subnets)
  common_tags = merge(var.default_tags, var.environment_tags)
  unique_azs = distinct(var.availability_zones)
}
```

### Q6: How do you use conditional expressions with functions?
**Answer:** 
```hcl
locals {
  instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"
  bucket_name = var.bucket_name != "" ? var.bucket_name : "default-bucket-${random_id.bucket.hex}"
  
  # Using can() function for error handling
  vpc_id = can(var.vpc_id) ? var.vpc_id : aws_vpc.default.id
}
```

### Q7: What are filesystem functions and when to use them?
**Answer:** 
- `file()` - Read file contents
- `fileexists()` - Check if file exists
- `fileset()` - Find files matching pattern
- `basename()` / `dirname()` - Get filename/directory
- `pathexpand()` - Expand ~ in paths
```hcl
locals {
  user_data = file("${path.module}/user-data.sh")
  config_files = fileset("${path.module}/configs", "*.conf")
  script_exists = fileexists("${path.module}/setup.sh")
}
```

## Advanced Questions

### Q8: How do you use templatefile() function?
**Answer:** `templatefile()` renders a template file with variables:
```hcl
# template.tpl
# server_name = "${server_name}"
# port = ${port}
# users = [
#   %{ for user in users ~}
#   "${user}",
#   %{ endfor ~}
# ]

locals {
  config = templatefile("${path.module}/template.tpl", {
    server_name = "web-server"
    port = 80
    users = ["admin", "user1"]
  })
}
```

### Q9: What are network functions and their use cases?
**Answer:** 
- `cidrhost()` - Get IP address from CIDR
- `cidrnetmask()` - Get netmask from CIDR
- `cidrsubnet()` - Calculate subnet CIDR
- `cidrsubnets()` - Calculate multiple subnets
```hcl
locals {
  vpc_cidr = "10.0.0.0/16"
  public_subnets = cidrsubnets(local.vpc_cidr, 8, 8, 8)
  private_subnets = cidrsubnets(local.vpc_cidr, 8, 8, 8)
  
  gateway_ip = cidrhost(local.vpc_cidr, 1)
}
```

### Q10: How do you use for expressions with functions?
**Answer:** 
```hcl
locals {
  # Transform list
  upper_names = [for name in var.names : upper(name)]
  
  # Transform map
  tagged_instances = {
    for k, v in var.instances :
    k => merge(v, {
      Name = format("%s-%s", var.prefix, k)
    })
  }
  
  # Filter and transform
  prod_instances = {
    for k, v in var.instances :
    k => v if contains(["prod", "production"], lower(v.environment))
  }
}
```

### Q11: What are encoding functions and their applications?
**Answer:** 
- `base64encode()` / `base64decode()` - Base64 encoding
- `jsonencode()` / `jsondecode()` - JSON encoding
- `yamlencode()` / `yamldecode()` - YAML encoding
- `urlencode()` - URL encoding
```hcl
locals {
  user_data = base64encode(templatefile("user-data.sh", {
    config = jsonencode(var.app_config)
  }))
  
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = var.policy_statements
  })
}
```

### Q12: How do you handle errors with try() and can() functions?
**Answer:** 
```hcl
locals {
  # try() returns first successful expression
  instance_type = try(var.instance_type, "t3.micro")
  
  # can() returns true if expression is valid
  has_custom_vpc = can(var.vpc_id)
  
  # Complex error handling
  database_config = try(
    jsondecode(var.database_config_json),
    {
      engine = "mysql"
      version = "8.0"
    }
  )
}
```

### Q13: What are best practices for using functions?
**Answer:** 
- Use functions to reduce code duplication
- Combine functions for complex transformations
- Use locals to store function results
- Handle errors gracefully with try() and can()
- Document complex function usage
- Test function expressions in terraform console

### Q14: How do you debug function expressions?
**Answer:** 
- Use `terraform console` to test expressions
- Add temporary outputs to see intermediate values
- Use `terraform plan` to see computed values
- Break complex expressions into smaller parts
```bash
# Test in console
terraform console
> upper("hello")
"HELLO"
> cidrsubnet("10.0.0.0/16", 8, 1)
"10.0.1.0/24"
```

### Q15: What are common function pitfalls?
**Answer:** 
- Not handling null values properly
- Using functions in resource names (causes recreation)
- Complex nested function calls (hard to debug)
- Not using try() for potentially failing expressions
- Forgetting that functions are evaluated during plan phase

