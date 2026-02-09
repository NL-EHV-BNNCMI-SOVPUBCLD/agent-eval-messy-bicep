#!/bin/bash
# Simple script to introduce drift on all deployed resources
# This creates realistic configuration drift for testing DriftGuard detection

set -e

RG_NAME="rg-messydrift-test"

echo "🎯 Introducing Configuration Drift on All Resources"
echo "===================================================="
echo "Resource Group: $RG_NAME"
echo ""

# Check prerequisites
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found"
    exit 1
fi

if ! az account show &> /dev/null; then
    echo "❌ Not logged into Azure. Run: az login"
    exit 1
fi

# Check if resource group exists
if ! az group show --name $RG_NAME &> /dev/null; then
    echo "❌ Resource group '$RG_NAME' not found"
    echo "   Deploy infrastructure first using GitHub Actions workflows"
    exit 1
fi

echo "🔍 Finding deployed resources..."
RESOURCES=$(az resource list --resource-group $RG_NAME --query "[].{name:name, type:type}" -o json)

if [ "$(echo $RESOURCES | jq '. | length')" -eq 0 ]; then
    echo "❌ No resources found in $RG_NAME"
    echo "   Deploy infrastructure first using GitHub Actions workflows"
    exit 1
fi

echo "✅ Found $(echo $RESOURCES | jq '. | length') resources"
echo ""

# Storage Account Drift
echo "📦 Modifying Storage Account..."
STORAGE_NAME=$(az storage account list -g $RG_NAME --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "$STORAGE_NAME" ]; then
    az storage account update \
      --name $STORAGE_NAME \
      --resource-group $RG_NAME \
      --allow-blob-public-access true \
      --tags Environment=DriftTest DriftType=PublicAccess 2>/dev/null || echo "  ⚠️  Could not modify storage"
    echo "  ✅ Enabled public blob access + added tags"
else
    echo "  ⏭️  No storage account found"
fi

# Network Security Group Drift
echo "🔒 Modifying Network Security Group..."
NSG_NAME=$(az network nsg list -g $RG_NAME --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "$NSG_NAME" ]; then
    # Try to add SSH rule (might already exist)
    az network nsg rule create \
      --resource-group $RG_NAME \
      --nsg-name $NSG_NAME \
      --name AllowSSH-Drift \
      --priority 200 \
      --source-address-prefixes '*' \
      --destination-port-ranges 22 \
      --access Allow \
      --protocol Tcp \
      --description "Drift testing SSH rule" 2>/dev/null || echo "  ⚠️  Rule might already exist"
    echo "  ✅ Added SSH rule"
else
    echo "  ⏭️  No NSG found"
fi

# Key Vault Drift
echo "🔑 Modifying Key Vault..."
KV_NAME=$(az keyvault list -g $RG_NAME --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "$KV_NAME" ]; then
    az keyvault update \
      --name $KV_NAME \
      --resource-group $RG_NAME \
      --retention-days 7 2>/dev/null || echo "  ⚠️  Could not modify Key Vault"
    az tag update \
      --resource-id $(az keyvault show -n $KV_NAME -g $RG_NAME --query id -o tsv) \
      --operation Merge \
      --tags DriftTest=true 2>/dev/null || true
    echo "  ✅ Changed soft-delete retention + added tags"
else
    echo "  ⏭️  No Key Vault found"
fi

# Virtual Network Drift
echo "🌐 Modifying Virtual Network..."
VNET_NAME=$(az network vnet list -g $RG_NAME --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "$VNET_NAME" ]; then
    az tag update \
      --resource-id $(az network vnet show -n $VNET_NAME -g $RG_NAME --query id -o tsv) \
      --operation Merge \
      --tags Environment=Drift NetworkType=Modified 2>/dev/null || true
    echo "  ✅ Added drift tags"
else
    echo "  ⏭️  No VNet found"
fi

# Container Registry Drift
echo "📦 Modifying Container Registry..."
ACR_NAME=$(az acr list -g $RG_NAME --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "$ACR_NAME" ]; then
    az tag update \
      --resource-id $(az acr show -n $ACR_NAME -g $RG_NAME --query id -o tsv) \
      --operation Merge \
      --tags DriftTest=true ModifiedBy=Script 2>/dev/null || true
    echo "  ✅ Added drift tags"
else
    echo "  ⏭️  No ACR found"
fi

# Web App Drift
echo "🌐 Modifying Web App..."
WEBAPP_NAME=$(az webapp list -g $RG_NAME --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "$WEBAPP_NAME" ]; then
    az webapp config appsettings set \
      --name $WEBAPP_NAME \
      --resource-group $RG_NAME \
      --settings DRIFT_TEST=true MODIFIED_BY_SCRIPT=yes 2>/dev/null || echo "  ⚠️  Could not modify app settings"
    echo "  ✅ Added app settings"
else
    echo "  ⏭️  No Web App found"
fi

# Cosmos DB Drift
echo "🗄️  Modifying Cosmos DB..."
COSMOS_NAME=$(az cosmosdb list -g $RG_NAME --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "$COSMOS_NAME" ]; then
    az tag update \
      --resource-id $(az cosmosdb show -n $COSMOS_NAME -g $RG_NAME --query id -o tsv) \
      --operation Merge \
      --tags DatabaseDrift=true 2>/dev/null || true
    echo "  ✅ Added drift tags"
else
    echo "  ⏭️  No Cosmos DB found"
fi

# SQL Server Drift
echo "🗄️  Modifying SQL Server..."
SQL_SERVER=$(az sql server list -g $RG_NAME --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "$SQL_SERVER" ]; then
    az sql server firewall-rule create \
      --resource-group $RG_NAME \
      --server $SQL_SERVER \
      --name AllowDriftTest \
      --start-ip-address 10.0.0.1 \
      --end-ip-address 10.0.0.255 2>/dev/null || echo "  ⚠️  Rule might already exist"
    echo "  ✅ Added firewall rule"
else
    echo "  ⏭️  No SQL Server found"
fi

# VM Drift
echo "💻 Modifying Virtual Machine..."
VM_NAME=$(az vm list -g $RG_NAME --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "$VM_NAME" ]; then
    az tag update \
      --resource-id $(az vm show -n $VM_NAME -g $RG_NAME --query id -o tsv) \
      --operation Merge \
      --tags DriftTest=true VMModified=yes 2>/dev/null || true
    echo "  ✅ Added drift tags"
else
    echo "  ⏭️  No VM found"
fi

# Application Insights Drift
echo "📊 Modifying Application Insights..."
APPINSIGHTS_NAME=$(az monitor app-insights component show -g $RG_NAME --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "$APPINSIGHTS_NAME" ]; then
    az monitor app-insights component update \
      --app $APPINSIGHTS_NAME \
      --resource-group $RG_NAME \
      --retention-time 30 2>/dev/null || echo "  ⚠️  Could not modify retention"
    echo "  ✅ Changed retention period"
else
    echo "  ⏭️  No App Insights found"
fi

echo ""
echo "✅ Drift introduced on all resources!"
echo ""
echo "Next steps:"
echo "  1. Run: ./test-driftguard.sh"
echo "  2. Review drift detection results"
echo "  3. Test auto-fix with: docker run ... --autofix"
echo ""
