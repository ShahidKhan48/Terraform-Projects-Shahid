# VPC Peering Connection
resource "aws_vpc_peering_connection" "main" {
  peer_vpc_id = var.peer_vpc_id
  vpc_id      = var.vpc_id
  peer_region = var.peer_region

  auto_accept = var.auto_accept

  tags = {
    Name        = "${var.project_name}-peering"
    Environment = var.environment
  }
}

# Accept VPC Peering Connection (for cross-region)
resource "aws_vpc_peering_connection_accepter" "peer" {
  count                     = var.peer_region != null ? 1 : 0
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  auto_accept               = true

  tags = {
    Name        = "${var.project_name}-peering-accepter"
    Environment = var.environment
  }
}

# Route for VPC Peering - Main VPC
resource "aws_route" "main_to_peer" {
  count                     = length(var.main_route_table_ids)
  route_table_id            = var.main_route_table_ids[count.index]
  destination_cidr_block    = var.peer_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
}

# Route for VPC Peering - Peer VPC
resource "aws_route" "peer_to_main" {
  count                     = length(var.peer_route_table_ids)
  route_table_id            = var.peer_route_table_ids[count.index]
  destination_cidr_block    = var.main_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
}

# Security Group Rules for Peering
resource "aws_security_group_rule" "allow_peering_ingress" {
  count             = length(var.security_group_ids)
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = [var.peer_vpc_cidr]
  security_group_id = var.security_group_ids[count.index]
}

resource "aws_security_group_rule" "allow_peering_egress" {
  count             = length(var.security_group_ids)
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = [var.peer_vpc_cidr]
  security_group_id = var.security_group_ids[count.index]
}