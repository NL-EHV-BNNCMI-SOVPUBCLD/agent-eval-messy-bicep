#!/bin/bash
# Setup script for Azure authentication with GitHub Actions

set -e

echo "🔧 Azure + GitHub Actions Setup for Drift Detection Testing"
echo "============================================================"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found. Please install: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "⚠️  GitHub CLI not found. You'll need to manually add secrets to GitHub."
    echo "   Install from: https://cli.github.com/"
    echo ""
fi

# Login check
echo "Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo "Please login to Azure:"
    az login
fi

# Get current subscription
SUBSCRIPTION_ID="83b81144-5906-45f5-87d5-805ad41e037c"
SUBSCRIPTION_NAME="ATOS BNN DEV PE"
TENANT_ID="b414b289-2018-4859-88d3-4765e51fb26e"

echo "✅ Using subscription: $SUBSCRIPTION_NAME"
echo "   Subscription ID: $SUBSCRIPTION_ID"
echo "   Tenant ID: $TENANT_ID"
echo ""

# Prompt for App Registration name
#read -p "Enter name for Azure AD App Registration [sp-drift-test-github]: " APP_NAME
APP_NAME="sp-messydrift-test-github"

# Create shared resource group
RG_NAME="rg-messydrift-test"
echo "📦 Creating shared resource group: $RG_NAME"
az group create --name $RG_NAME --location westeurope --output none

# Create Service Principal
echo "👤 Creating Service Principal: $APP_NAME"
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "$APP_NAME" \
  --role contributor \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME" \
  --output json)

CLIENT_ID=$(echo $SP_OUTPUT | jq -r '.appId')
echo "✅ Service Principal created"
echo "   Client ID: $CLIENT_ID"
echo ""

# Add federated credential for GitHub
read -p "Enter GitHub repository (format: owner/repo) [NL-EHV-BNNCMI-SOVPUBCLD/agent-eval-messy-bicep]: " GITHUB_REPO
GITHUB_REPO=${GITHUB_REPO:-NL-EHV-BNNCMI-SOVPUBCLD/agent-eval-messy-bicep}

read -p "Enter branch name [main]: " BRANCH_NAME
BRANCH_NAME=${BRANCH_NAME:-main}

echo "🔐 Adding federated credential for GitHub Actions..."
az ad app federated-credential create \
  --id $CLIENT_ID \
  --parameters "{
    \"name\": \"github-actions-$BRANCH_NAME\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_REPO:ref:refs/heads/$BRANCH_NAME\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" --output none

echo "✅ Federated credential added for main branch"

# Add federated credential for pull requests
az ad app federated-credential create \
  --id $CLIENT_ID \
  --parameters "{
    \"name\": \"github-actions-pr\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_REPO:pull_request\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" --output none 2>/dev/null && echo "✅ Federated credential added for pull requests" || echo "⚠️  PR credential may already exist"

echo ""
echo "============================================================"
echo "🎉 Setup Complete!"
echo "============================================================"
echo ""
echo "Add these secrets to your GitHub repository:"
echo "GitHub → Settings → Secrets and variables → Actions → New repository secret"
echo ""
echo "Secret Name              | Secret Value"
echo "------------------------|------------------------------------------"
echo "AZURE_CLIENT_ID         | $CLIENT_ID"
echo "AZURE_TENANT_ID         | $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID   | $SUBSCRIPTION_ID"
echo ""


# Optionally add secrets via GitHub CLI
if command -v gh &> /dev/null; then
    echo ""
    read -p "Would you like to add these secrets automatically using GitHub CLI? (y/n): " ADD_SECRETS
    if [[ $ADD_SECRETS == "y" || $ADD_SECRETS == "Y" ]]; then
        echo "Adding secrets to GitHub..."
        
        # Check if authenticated
        if gh auth status &> /dev/null; then
            cd "$(git rev-parse --show-toplevel)"
            
            echo -n "$CLIENT_ID" | gh secret set AZURE_CLIENT_ID
            echo -n "$TENANT_ID" | gh secret set AZURE_TENANT_ID
            echo -n "$SUBSCRIPTION_ID" | gh secret set AZURE_SUBSCRIPTION_ID
            
            echo "✅ Secrets added to GitHub repository"
            echo ""
            echo "You can now run workflows from GitHub Actions!"
        else
            echo "Please authenticate with GitHub CLI first:"
            echo "  gh auth login"
        fi
    fi
fi

echo ""
echo "Next steps:"
echo "1. Verify secrets are set in GitHub: https://github.com/$GITHUB_REPO/settings/secrets/actions"
echo "2. (Optional) Create GitHub environments: dev, staging, prod"
echo "3. Run a workflow: gh workflow run full-stack-deploy.yml -f environment=dev -f resource_group_prefix=rg-drift-test"
echo ""
echo "To clean up Azure resources later:"
echo "  az ad sp delete --id $CLIENT_ID"
echo "  az group delete --name $RG_NAME --yes"
echo ""
