module "vpc" {
  source = "git::https://github.com/PlatformStackPulse/tf-atom-vpc-aws.git?ref=v1.1.0"

  enabled   = module.this.enabled
  namespace = var.namespace
  name      = var.name
  stage     = var.stage
  tags      = var.tags

  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
}

module "internet_gateway" {
  source = "git::https://github.com/PlatformStackPulse/tf-atom-internet-gateway-aws.git?ref=v1.1.0"

  enabled   = module.this.enabled
  namespace = var.namespace
  name      = "${var.name}-igw"
  stage     = var.stage
  tags      = var.tags

  vpc_id = module.vpc.id
}

module "public_subnets" {
  source   = "git::https://github.com/PlatformStackPulse/tf-atom-subnet-aws.git?ref=v1.1.0"
  for_each = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }

  enabled   = module.this.enabled
  namespace = var.namespace
  name      = "${var.name}-public-${each.key}"
  stage     = var.stage
  tags      = merge(var.tags, { Tier = "public" })

  vpc_id                  = module.vpc.id
  cidr_block              = each.value
  availability_zone       = var.availability_zones[each.key]
  map_public_ip_on_launch = true
}

module "private_subnets" {
  source   = "git::https://github.com/PlatformStackPulse/tf-atom-subnet-aws.git?ref=v1.1.0"
  for_each = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }

  enabled   = module.this.enabled
  namespace = var.namespace
  name      = "${var.name}-private-${each.key}"
  stage     = var.stage
  tags      = merge(var.tags, { Tier = "private" })

  vpc_id            = module.vpc.id
  cidr_block        = each.value
  availability_zone = var.availability_zones[each.key]
}

module "eip" {
  source   = "git::https://github.com/PlatformStackPulse/tf-atom-eip-aws.git?ref=v1.1.0"
  for_each = var.nat_gateway_enabled ? { for idx in range(var.nat_gateway_count) : idx => idx } : {}

  enabled   = module.this.enabled
  namespace = var.namespace
  name      = "${var.name}-nat-${each.key}"
  stage     = var.stage
  tags      = var.tags
}

module "nat_gateway" {
  source   = "git::https://github.com/PlatformStackPulse/tf-atom-nat-gateway-aws.git?ref=v1.1.0"
  for_each = var.nat_gateway_enabled ? { for idx in range(var.nat_gateway_count) : idx => idx } : {}

  enabled   = module.this.enabled
  namespace = var.namespace
  name      = "${var.name}-nat-${each.key}"
  stage     = var.stage
  tags      = var.tags

  allocation_id = module.eip[each.key].allocation_id
  subnet_id     = module.public_subnets[each.key].id
}

module "public_route_table" {
  source = "git::https://github.com/PlatformStackPulse/tf-atom-route-table-aws.git?ref=v1.1.0"

  enabled   = module.this.enabled
  namespace = var.namespace
  name      = "${var.name}-public"
  stage     = var.stage
  tags      = var.tags

  vpc_id = module.vpc.id
}

module "public_route" {
  source = "git::https://github.com/PlatformStackPulse/tf-atom-route-aws.git?ref=v1.1.0"

  enabled   = module.this.enabled
  namespace = var.namespace
  name      = "${var.name}-public-igw"
  stage     = var.stage
  tags      = var.tags

  route_table_id         = module.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = module.internet_gateway.id
}

module "public_route_table_associations" {
  source   = "git::https://github.com/PlatformStackPulse/tf-atom-route-table-association-aws.git?ref=v1.1.0"
  for_each = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }

  enabled   = module.this.enabled
  namespace = var.namespace
  name      = "${var.name}-public-rta-${each.key}"
  stage     = var.stage
  tags      = var.tags

  subnet_id      = module.public_subnets[each.key].id
  route_table_id = module.public_route_table.id
}

module "private_route_tables" {
  source   = "git::https://github.com/PlatformStackPulse/tf-atom-route-table-aws.git?ref=v1.1.0"
  for_each = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }

  enabled   = module.this.enabled
  namespace = var.namespace
  name      = "${var.name}-private-${each.key}"
  stage     = var.stage
  tags      = var.tags

  vpc_id = module.vpc.id
}

module "private_routes" {
  source   = "git::https://github.com/PlatformStackPulse/tf-atom-route-aws.git?ref=v1.1.0"
  for_each = var.nat_gateway_enabled ? { for idx, cidr in var.private_subnet_cidrs : idx => cidr } : {}

  enabled   = module.this.enabled
  namespace = var.namespace
  name      = "${var.name}-private-nat-${each.key}"
  stage     = var.stage
  tags      = var.tags

  route_table_id         = module.private_route_tables[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = module.nat_gateway[each.key % var.nat_gateway_count].id
}

module "private_route_table_associations" {
  source   = "git::https://github.com/PlatformStackPulse/tf-atom-route-table-association-aws.git?ref=v1.1.0"
  for_each = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }

  enabled   = module.this.enabled
  namespace = var.namespace
  name      = "${var.name}-private-rta-${each.key}"
  stage     = var.stage
  tags      = var.tags

  subnet_id      = module.private_subnets[each.key].id
  route_table_id = module.private_route_tables[each.key].id
}
