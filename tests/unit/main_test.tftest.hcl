# Unit Tests for tf-molecule-vpc-network-aws
#
# These tests use a mock AWS provider — no real AWS calls are made.
# Run with:         terraform test -test-directory=tests/unit
# Run verbose:      terraform test -test-directory=tests/unit -verbose
# Run one:          terraform test -test-directory=tests/unit -run "creates_when_enabled"
#
# NOTE: Assertions only reference values that are KNOWN at plan time under a
# mock provider (tf-label id strings, for_each cardinality, input pass-throughs).
# Computed values such as real VPC/subnet arns/ids are unknown under a mock
# provider and MUST NOT be asserted on.

mock_provider "aws" {}

variables {
  # tf-label identity
  namespace = "eg"
  stage     = "test"
  name      = "thing"

  # Module-required inputs
  availability_zones = ["us-east-1a", "us-east-1b"]

  # Deterministic network layout (two public, two private subnets)
  vpc_cidr_block       = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  nat_gateway_enabled  = true
  nat_gateway_count    = 1
}

# ---------------------------------------------------------------------------
# Test: module wires up the expected network topology when enabled
# ---------------------------------------------------------------------------
run "creates_when_enabled" {
  command = plan

  # One public subnet id output entry per requested public CIDR (plan-known
  # because the for_each key set is derived from a static input list).
  assert {
    condition     = length(output.public_subnet_ids) == length(var.public_subnet_cidrs)
    error_message = "Expected one public subnet output per public_subnet_cidrs entry."
  }

  # One private subnet id output entry per requested private CIDR.
  assert {
    condition     = length(output.private_subnet_ids) == length(var.private_subnet_cidrs)
    error_message = "Expected one private subnet output per private_subnet_cidrs entry."
  }

  # NAT gateways are created (enabled) with the requested count.
  assert {
    condition     = length(output.nat_gateway_ids) == var.nat_gateway_count
    error_message = "Expected nat_gateway_ids length to equal nat_gateway_count when NAT is enabled."
  }
}

# ---------------------------------------------------------------------------
# Test: disabling NAT gateways drops the NAT + private-route resources
# ---------------------------------------------------------------------------
run "no_nat_when_disabled" {
  command = plan

  variables {
    nat_gateway_enabled = false
  }

  # nat_gateway for_each collapses to {} → no NAT gateway id outputs.
  assert {
    condition     = length(output.nat_gateway_ids) == 0
    error_message = "Expected zero NAT gateways when nat_gateway_enabled = false."
  }

  # Private/public subnet topology is unaffected by the NAT toggle.
  assert {
    condition     = length(output.private_subnet_ids) == length(var.private_subnet_cidrs)
    error_message = "Private subnets should still be planned when NAT is disabled."
  }
}

# ---------------------------------------------------------------------------
# Test: an empty subnet topology creates no subnet or NAT resources
# ---------------------------------------------------------------------------
# NOTE: This module keeps the tf-label `enabled` switch on its child atoms, but
# with `enabled = false` the VPC atom emits a null id that the IGW / route-table
# atoms reject via their own `length(var.vpc_id) > 0` validation — so the
# whole-module disable path cannot be planned in isolation. Instead we assert
# the "creates nothing at the subnet/NAT tier" contract by requesting an empty
# set of subnet CIDRs (every subnet/NAT for_each collapses to {}).
run "empty_topology_creates_no_subnets" {
  command = plan

  variables {
    public_subnet_cidrs  = []
    private_subnet_cidrs = []
    nat_gateway_enabled  = false
  }

  assert {
    condition     = length(output.public_subnet_ids) == 0
    error_message = "No public subnet ids should be surfaced when public_subnet_cidrs is empty."
  }

  assert {
    condition     = length(output.private_subnet_ids) == 0
    error_message = "No private subnet ids should be surfaced when private_subnet_cidrs is empty."
  }

  assert {
    condition     = length(output.nat_gateway_ids) == 0
    error_message = "No NAT gateway ids should be surfaced when NAT is disabled."
  }
}
