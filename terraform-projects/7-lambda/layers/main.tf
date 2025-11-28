# Lambda Layer
resource "aws_lambda_layer_version" "main" {
  count               = length(var.lambda_layers)
  filename            = var.lambda_layers[count.index].filename
  layer_name          = var.lambda_layers[count.index].layer_name
  description         = var.lambda_layers[count.index].description
  compatible_runtimes = var.lambda_layers[count.index].compatible_runtimes
  license_info        = var.lambda_layers[count.index].license_info
  source_code_hash    = var.lambda_layers[count.index].source_code_hash

  tags = {
    Name        = var.lambda_layers[count.index].layer_name
    Environment = var.environment
  }
}

# Lambda Layer from S3
resource "aws_lambda_layer_version" "from_s3" {
  count               = length(var.lambda_layers_from_s3)
  s3_bucket           = var.lambda_layers_from_s3[count.index].s3_bucket
  s3_key              = var.lambda_layers_from_s3[count.index].s3_key
  s3_object_version   = var.lambda_layers_from_s3[count.index].s3_object_version
  layer_name          = var.lambda_layers_from_s3[count.index].layer_name
  description         = var.lambda_layers_from_s3[count.index].description
  compatible_runtimes = var.lambda_layers_from_s3[count.index].compatible_runtimes
  license_info        = var.lambda_layers_from_s3[count.index].license_info

  tags = {
    Name        = var.lambda_layers_from_s3[count.index].layer_name
    Environment = var.environment
  }
}

# Lambda Layer Permission
resource "aws_lambda_layer_version_permission" "main" {
  count          = length(var.layer_permissions)
  layer_name     = var.layer_permissions[count.index].layer_name
  version_number = var.layer_permissions[count.index].version_number
  statement_id   = var.layer_permissions[count.index].statement_id
  action         = var.layer_permissions[count.index].action
  principal      = var.layer_permissions[count.index].principal
  organization_id = var.layer_permissions[count.index].organization_id
}

# Common Lambda Layers
resource "aws_lambda_layer_version" "python_requests" {
  count               = var.create_python_requests_layer ? 1 : 0
  filename            = "python-requests-layer.zip"
  layer_name          = "${var.project_name}-python-requests"
  description         = "Python requests library layer"
  compatible_runtimes = ["python3.8", "python3.9", "python3.10", "python3.11"]

  tags = {
    Name        = "${var.project_name}-python-requests"
    Environment = var.environment
  }
}

resource "aws_lambda_layer_version" "nodejs_axios" {
  count               = var.create_nodejs_axios_layer ? 1 : 0
  filename            = "nodejs-axios-layer.zip"
  layer_name          = "${var.project_name}-nodejs-axios"
  description         = "Node.js axios library layer"
  compatible_runtimes = ["nodejs14.x", "nodejs16.x", "nodejs18.x"]

  tags = {
    Name        = "${var.project_name}-nodejs-axios"
    Environment = var.environment
  }
}

resource "aws_lambda_layer_version" "python_pandas" {
  count               = var.create_python_pandas_layer ? 1 : 0
  filename            = "python-pandas-layer.zip"
  layer_name          = "${var.project_name}-python-pandas"
  description         = "Python pandas library layer"
  compatible_runtimes = ["python3.8", "python3.9", "python3.10", "python3.11"]

  tags = {
    Name        = "${var.project_name}-python-pandas"
    Environment = var.environment
  }
}