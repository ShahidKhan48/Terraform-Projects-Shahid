# Transit Gateway
resource "aws_ec2_transit_gateway" "main" {
  description                     = "Transit Gateway for ${var.project_name}"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support               = "enable"

  tags = {
    Name        = "${var.project_name}-tgw"
    Environment = var.environment
  }
}

# Transit Gateway VPC Attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_attachments" {
  count          = length(var.vpc_attachments)
  subnet_ids     = var.vpc_attachments[count.index].subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id         = var.vpc_attachments[count.index].vpc_id

  tags = {
    Name        = "${var.project_name}-tgw-attachment-${count.index + 1}"
    Environment = var.environment
  }
}

# Transit Gateway Route Table
resource "aws_ec2_transit_gateway_route_table" "main" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name        = "${var.project_name}-tgw-rt"
    Environment = var.environment
  }
}

# Transit Gateway Routes
resource "aws_ec2_transit_gateway_route" "routes" {
  count                          = length(var.tgw_routes)
  destination_cidr_block         = var.tgw_routes[count.index].destination_cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_attachments[var.tgw_routes[count.index].attachment_index].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

# Transit Gateway Route Table Associations
resource "aws_ec2_transit_gateway_route_table_association" "associations" {
  count                          = length(aws_ec2_transit_gateway_vpc_attachment.vpc_attachments)
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_attachments[count.index].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

# Transit Gateway Route Table Propagations
resource "aws_ec2_transit_gateway_route_table_propagation" "propagations" {
  count                          = length(aws_ec2_transit_gateway_vpc_attachment.vpc_attachments)
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_attachments[count.index].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

# VPC Routes to Transit Gateway
resource "aws_route" "to_tgw" {
  count                  = length(var.vpc_routes_to_tgw)
  route_table_id         = var.vpc_routes_to_tgw[count.index].route_table_id
  destination_cidr_block = var.vpc_routes_to_tgw[count.index].destination_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.vpc_attachments]
}