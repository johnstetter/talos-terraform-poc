#!/bin/bash

# Proxmox Permission Setup Script for Talos Terraform
# This script creates the necessary user, role, and permissions for Terraform automation

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

echo -e "${BLUE}🔧 Setting up Proxmox permissions for Terraform Talos deployment${NC}"
echo

# Check if we're running on Proxmox
if ! command -v pveum &> /dev/null; then
    echo -e "${RED}❌ Error: pveum command not found. This script must be run on a Proxmox VE server.${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Configuration:${NC}"
echo "  User: $TERRAFORM_USER"
echo "  Role: $TERRAFORM_ROLE"
echo "  Token ID: $TOKEN_ID"
echo

# Create the terraform user if it doesn't exist
echo -e "${BLUE}👤 Creating Terraform user...${NC}"
if pveum user list | grep -q "^│ $TERRAFORM_USER"; then
    echo -e "${GREEN}✅ User $TERRAFORM_USER already exists${NC}"
else
    pveum user add $TERRAFORM_USER --comment "Terraform automation user for Talos deployments"
    echo -e "${GREEN}✅ Created user $TERRAFORM_USER${NC}"
fi

# Create the terraform role with all required permissions
echo -e "${BLUE}🔐 Creating Terraform role with required permissions...${NC}"
REQUIRED_PERMISSIONS=(
    "Datastore.AllocateSpace"
    "Datastore.AllocateTemplate"
    "Datastore.Audit"
    "Pool.Allocate"
    "SDN.Use"
    "Sys.Audit"
    "Sys.Console"
    "Sys.Modify"
    "VM.Allocate"
    "VM.Audit"
    "VM.Clone"
    "VM.Config.CDROM"
    "VM.Config.CPU"
    "VM.Config.Cloudinit"
    "VM.Config.Disk"
    "VM.Config.HWType"
    "VM.Config.Memory"
    "VM.Config.Network"
    "VM.Config.Options"
    "VM.Console"
    "VM.Migrate"
    "VM.Monitor"
    "VM.PowerMgmt"
)

# Join permissions with commas
PERMISSIONS=$(IFS=,; echo "${REQUIRED_PERMISSIONS[*]}")

if pveum role list | grep -q "^│ $TERRAFORM_ROLE"; then
    echo -e "${YELLOW}⚠️  Role $TERRAFORM_ROLE exists, updating permissions...${NC}"
    pveum role modify $TERRAFORM_ROLE --privs "$PERMISSIONS"
else
    pveum role add $TERRAFORM_ROLE --privs "$PERMISSIONS"
fi
echo -e "${GREEN}✅ Created/updated role $TERRAFORM_ROLE${NC}"

# Assign role to user at root level
echo -e "${BLUE}🎭 Assigning role to user...${NC}"
pveum acl modify / --users $TERRAFORM_USER --roles $TERRAFORM_ROLE
echo -e "${GREEN}✅ Assigned $TERRAFORM_ROLE to $TERRAFORM_USER at root level${NC}"

# Create API token
echo -e "${BLUE}🔑 Creating API token...${NC}"
if pveum user token list $TERRAFORM_USER | grep -q "$TOKEN_ID"; then
    echo -e "${YELLOW}⚠️  Token $TOKEN_ID already exists. Delete it first if you want to recreate it:${NC}"
    echo "    pveum user token remove $TERRAFORM_USER $TOKEN_ID"
    echo
    echo -e "${BLUE}📝 To get the existing token (if you forgot it), you'll need to recreate it:${NC}"
    echo "    pveum user token remove $TERRAFORM_USER $TOKEN_ID"
    echo "    pveum user token add $TERRAFORM_USER $TOKEN_ID --privsep 0"
else
    echo -e "${GREEN}Creating new API token...${NC}"
    TOKEN_OUTPUT=$(pveum user token add $TERRAFORM_USER $TOKEN_ID --privsep 0)

    echo
    echo -e "${GREEN}✅ API Token created successfully!${NC}"
    echo -e "${YELLOW}🚨 IMPORTANT: Save this token - you won't see it again!${NC}"
    echo
    echo -e "${BLUE}Token for terraform.tfvars:${NC}"
    echo "proxmox_api_token = \"$TERRAFORM_USER!$TOKEN_ID=$(echo "$TOKEN_OUTPUT" | grep -o '[a-f0-9-]\{36\}')\""
    echo
    echo -e "${BLUE}Token for .env file:${NC}"
    echo "TF_VAR_proxmox_api_token=$TERRAFORM_USER!$TOKEN_ID=$(echo "$TOKEN_OUTPUT" | grep -o '[a-f0-9-]\{36\}')"
    echo
fi

echo -e "${GREEN}🎉 Proxmox permissions setup complete!${NC}"
echo
echo -e "${BLUE}📋 Summary of what was created:${NC}"
echo "  ✅ User: $TERRAFORM_USER"
echo "  ✅ Role: $TERRAFORM_ROLE (with $(echo "${REQUIRED_PERMISSIONS[@]}" | wc -w) permissions)"
echo "  ✅ Token: $TERRAFORM_USER!$TOKEN_ID"
echo "  ✅ ACL: Root level access"
echo
echo -e "${BLUE}🚀 Next steps:${NC}"
echo "  1. Copy the token to your terraform.tfvars or .env file"
echo "  2. Ensure your SSH key is loaded: ssh-add ~/.ssh/id_ed25519"
echo "  3. Run: devbox run apply"
echo
echo -e "${YELLOW}💡 Tip: You can verify permissions with:${NC}"
echo "    pveum user list | grep terraform"
echo "    pveum acl list | grep terraform"