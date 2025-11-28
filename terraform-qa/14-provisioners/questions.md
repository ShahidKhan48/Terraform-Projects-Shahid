# Terraform Provisioners - Q&A

## Basic Questions

### Q1: What are Terraform provisioners?
**Answer:** Provisioners are used to execute scripts on a local or remote machine as part of resource creation or destruction. They are considered a "last resort" and should be avoided when possible in favor of native Terraform resources or cloud-init/user data.

### Q2: What are the main types of provisioners?
**Answer:** 
- **file**: Copies files or directories from local to remote machine
- **remote-exec**: Executes commands on remote machine via SSH or WinRM
- **local-exec**: Executes commands on local machine where Terraform runs

### Q3: When should you use provisioners?
**Answer:** Use provisioners only when:
- No native Terraform resource exists for the task
- Cloud-init or user data is insufficient
- You need to perform actions during resource destruction
- Integrating with external systems that don't have Terraform providers

## Intermediate Questions

### Q4: How do you use the file provisioner?
**Answer:** 
```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  key_name      = "my-keypair"
  
  # Copy single file
  provisioner "file" {
    source      = "app.conf"
    destination = "/tmp/app.conf"
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
  
  # Copy directory
  provisioner "file" {
    source      = "configs/"
    destination = "/tmp"
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
}
```

### Q5: How do you use the remote-exec provisioner?
**Answer:** 
```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  
  # Inline commands
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y httpd",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd"
    ]
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
  
  # Execute script file
  provisioner "remote-exec" {
    script = "${path.module}/setup.sh"
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
}
```

### Q6: How do you use the local-exec provisioner?
**Answer:** 
```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  
  # Simple command
  provisioner "local-exec" {
    command = "echo 'Instance ${self.id} created'"
  }
  
  # Complex command with environment variables
  provisioner "local-exec" {
    command = "aws ec2 create-tags --resources ${self.id} --tags Key=CreatedBy,Value=Terraform"
    
    environment = {
      AWS_DEFAULT_REGION = "us-west-2"
    }
  }
  
  # Working directory and interpreter
  provisioner "local-exec" {
    command     = "python3 notify.py --instance-id ${self.id}"
    working_dir = "${path.module}/scripts"
    interpreter = ["python3", "-c"]
  }
}
```

### Q7: How do you configure connections for provisioners?
**Answer:** 
```hcl
# SSH Connection
connection {
  type        = "ssh"
  user        = "ec2-user"
  private_key = file("~/.ssh/id_rsa")
  host        = self.public_ip
  port        = 22
  timeout     = "5m"
  
  # Bastion host
  bastion_host        = "bastion.example.com"
  bastion_user        = "bastion-user"
  bastion_private_key = file("~/.ssh/bastion_key")
}

# WinRM Connection (Windows)
connection {
  type     = "winrm"
  user     = "Administrator"
  password = var.admin_password
  host     = self.public_ip
  port     = 5985
  https    = false
  insecure = true
  timeout  = "10m"
}
```

## Advanced Questions

### Q8: How do you use destruction-time provisioners?
**Answer:** 
```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  
  # Cleanup on destroy
  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Instance ${self.id} is being destroyed'"
  }
  
  # Remote cleanup
  provisioner "remote-exec" {
    when = destroy
    
    inline = [
      "sudo systemctl stop httpd",
      "sudo rm -rf /var/www/html/*"
    ]
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
}
```

### Q9: How do you handle provisioner failures?
**Answer:** 
```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  
  # Continue on failure
  provisioner "remote-exec" {
    on_failure = continue
    
    inline = [
      "sudo yum install -y optional-package || true"
    ]
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
  
  # Fail on error (default)
  provisioner "remote-exec" {
    on_failure = fail
    
    inline = [
      "sudo yum install -y required-package"
    ]
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
}
```

### Q10: How do you use provisioners with templates?
**Answer:** 
```hcl
# Template file: setup.sh.tpl
# #!/bin/bash
# SERVER_NAME="${server_name}"
# DATABASE_HOST="${db_host}"
# API_KEY="${api_key}"
# 
# echo "Setting up $SERVER_NAME..."
# echo "DATABASE_HOST=$DATABASE_HOST" >> /etc/environment

resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  
  provisioner "file" {
    content = templatefile("${path.module}/setup.sh.tpl", {
      server_name = "web-server"
      db_host     = aws_db_instance.main.endpoint
      api_key     = var.api_key
    })
    destination = "/tmp/setup.sh"
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
  
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup.sh",
      "/tmp/setup.sh"
    ]
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
}
```

### Q11: What are alternatives to provisioners?
**Answer:** 
- **User Data/Cloud-Init**: For initial instance configuration
- **Configuration Management**: Ansible, Chef, Puppet
- **Container Images**: Pre-configured Docker images
- **AMI/Image Building**: Packer for custom images
- **Native Resources**: Use provider-specific resources when available
- **External Tools**: Triggered via local-exec but managed separately

### Q12: What are provisioner best practices?
**Answer:** 
- Avoid provisioners when possible
- Use idempotent scripts
- Handle errors gracefully
- Use proper connection timeouts
- Secure credential management
- Test provisioner scripts independently
- Use version control for scripts
- Document provisioner dependencies
- Consider using null_resource for standalone provisioning

### Q13: How do you debug provisioner issues?
**Answer:** 
```hcl
# Enable detailed logging
provisioner "remote-exec" {
  inline = [
    "set -x",  # Enable bash debugging
    "whoami",
    "pwd",
    "ls -la",
    "sudo yum install -y httpd"
  ]
  
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }
}

# Test connection separately
provisioner "remote-exec" {
  inline = ["echo 'Connection successful'"]
  
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }
}
```

### Q14: What are common provisioner pitfalls?
**Answer:** 
- Not handling provisioner failures properly
- Using provisioners for tasks better suited to other tools
- Not making scripts idempotent
- Hardcoding values instead of using variables
- Not handling connection timeouts
- Using provisioners in production without proper testing
- Not considering provisioner execution order
- Ignoring security implications of remote execution

### Q15: How do you use null_resource with provisioners?
**Answer:** 
```hcl
# Standalone provisioning task
resource "null_resource" "setup_monitoring" {
  # Trigger on instance changes
  triggers = {
    instance_id = aws_instance.web.id
    config_hash = md5(file("${path.module}/monitoring.conf"))
  }
  
  provisioner "file" {
    source      = "monitoring.conf"
    destination = "/tmp/monitoring.conf"
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = aws_instance.web.public_ip
    }
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo cp /tmp/monitoring.conf /etc/monitoring/",
      "sudo systemctl restart monitoring-agent"
    ]
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = aws_instance.web.public_ip
    }
  }
  
  depends_on = [aws_instance.web]
}
```

