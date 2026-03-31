#!/bin/bash

# Proxmox Permission Cleanup Script for Talos Terraform
# This script removes the Terraform user, role, and permissions

set -e

# Configuration
TERRAFORM_USER="terraform@pve"
TERRAFORM_ROLE="TerraformTalos"
TOKEN_ID="talos-token"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 Cleaning up Proxmox permissions for Terraform Talos deployment${NC}"
echo

# Check if we're running on Proxmox
if ! command -v pveum &> /dev/null; then
    echo -e "${RED}❌ Error: pveum command not found. This script must be run on a Proxmox VE server.${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Will remove:${NC}"
echo "  User: $TERRAFORM_USER"
echo "  Role: $TERRAFORM_ROLE"
echo "  Token: $TOKEN_ID"
echo

read -p "Are you sure you want to remove these permissions? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}❌ Cancelled by user${NC}"
    exit 1
fi

# Remove API token
echo -e "${BLUE}🔑 Removing API token...${NC}"
if pveum user token list $TERRAFORM_USER 2>/dev/null | grep -q "$TOKEN_ID"; then
    pveum user token remove $TERRAFORM_USER $TOKEN_ID
    echo -e "${GREEN}✅ Removed token $TOKEN_ID${NC}"
else
    echo -e "${YELLOW}⚠️  Token $TOKEN_ID not found${NC}"
fi

# Remove ACL assignment
echo -e "${BLUE}🎭 Removing role assignment...${NC}"
if pveum acl list | grep -q "$TERRAFORM_USER"; then
    pveum acl delete / --users $TERRAFORM_USER
    echo -e "${GREEN}✅ Removed ACL for $TERRAFORM_USER${NC}"
else
    echo -e "${YELLOW}⚠️  No ACL found for $TERRAFORM_USER${NC}"
fi

# Remove user
echo -e "${BLUE}👤 Removing user...${NC}"
if pveum user list | grep -q "^│ $TERRAFORM_USER"; then
    pveum user delete $TERRAFORM_USER
    echo -e "${GREEN}✅ Removed user $TERRAFORM_USER${NC}"
else
    echo -e "${YELLOW}⚠️  User $TERRAFORM_USER not found${NC}"
fi

# Check if role is used by other users/tokens before removing
echo -e "${BLUE}🔐 Checking if role is used by others...${NC}"
if pveum acl list | grep -q "$TERRAFORM_ROLE" || pveum user list | grep -q "$TERRAFORM_ROLE"; then
    echo -e "${YELLOW}⚠️  Role $TERRAFORM_ROLE is still used by other users/tokens, not removing${NC}"
else
    if pveum role list | grep -q "^│ $TERRAFORM_ROLE"; then
        pveum role delete $TERRAFORM_ROLE
        echo -e "${GREEN}✅ Removed role $TERRAFORM_ROLE${NC}"
    else
        echo -e "${YELLOW}⚠️  Role $TERRAFORM_ROLE not found${NC}"
    fi
fi

echo
echo -e "${GREEN}🎉 Cleanup complete!${NC}"
echo
echo -e "${BLUE}💡 Tip: You can verify removal with:${NC}"
echo "    pveum user list | grep terraform"
echo "    pveum role list | grep terraform"
echo "    pveum acl list | grep terraform"