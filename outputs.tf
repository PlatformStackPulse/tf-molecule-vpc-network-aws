output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = [for s in module.public_subnets : s.id]
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = [for s in module.private_subnets : s.id]
}

output "nat_gateway_ids" {
  description = "IDs of NAT gateways"
  value       = [for n in module.nat_gateway : n.id]
}

output "internet_gateway_id" {
  description = "ID of the internet gateway"
  value       = module.internet_gateway.id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = module.public_route_table.id
}

output "private_route_table_ids" {
  description = "IDs of private route tables"
  value       = [for rt in module.private_route_tables : rt.id]
}
