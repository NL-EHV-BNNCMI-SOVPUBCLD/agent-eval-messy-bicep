#!/bin/bash
# Helper script for common drift detection testing scenarios

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔍 Drift Detection Testing Helper"
echo "=================================="
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

# Menu
echo "Select a drift testing scenario:"
echo ""
echo "1) Deploy base infrastructure (for clean state)"
echo "2) Introduce manual drift (modify deployed resources)"
echo "3) Generate drift report (compare deployed vs IaC)"
echo "4) List all deployed resources in RG"
echo "5) Export deployed resources as ARM template"
echo "6) Clean up all test resources"
echo ""
read -p "Enter choice [1-6]: " CHOICE

case $CHOICE in
  1)
    echo ""
    read -p "Enter resource group name [rg-drift-test-manual]: " RG_NAME
    RG_NAME=${RG_NAME:-rg-drift-test-manual}
    
    read -p "Enter location [westeurope]: " LOCATION
    LOCATION=${LOCATION:-westeurope}
    
    echo "📦 Creating resource group: $RG_NAME"
    az group create --name $RG_NAME --location $LOCATION
    
    echo "🚀 Deploying baseline infrastructure..."
    
    # Deploy Storage
    echo "  → Deploying Storage Account..."
    az deployment group create \
      --resource-group $RG_NAME \
      --template-file "$REPO_ROOT/storage.bicep" \
      --parameters "$REPO_ROOT/temp/params/storage-params.json" \
      --name storage-baseline \
      --output none
    
    # Deploy NSG
    echo "  → Deploying Network Security Group..."
    az deployment group create \
      --resource-group $RG_NAME \
      --parameters "$REPO_ROOT/configs/nsg-config.bicepparam" \
      --name nsg-baseline \
      --output none
    
    # Deploy Key Vault
    echo "  → Deploying Key Vault..."
    az deployment group create \
      --resource-group $RG_NAME \
      --parameters "$REPO_ROOT/random/stuff/kv.bicepparam" \
      --name kv-baseline \
      --output none
    
    echo "✅ Baseline infrastructure deployed!"
    echo ""
    echo "Run scenario 2 to introduce drift, then scenario 3 to detect it."
    ;;
    
  2)
    echo ""
    read -p "Enter resource group name: " RG_NAME
    
    echo "🎯 Introducing configuration drift..."
    echo ""
    echo "Select drift type:"
    echo "1) Modify Storage Account (change to allow public blob access)"
    echo "2) Add NSG rule (allow SSH)"
    echo "3) Disable Key Vault soft delete"
    echo "4) Change Storage SKU"
    echo ""
    read -p "Enter choice [1-4]: " DRIFT_TYPE
    
    case $DRIFT_TYPE in
      1)
        echo "Modifying Storage Account..."
        STORAGE_NAME=$(az storage account list -g $RG_NAME --query "[0].name" -o tsv)
        az storage account update \
          --name $STORAGE_NAME \
          --resource-group $RG_NAME \
          --allow-blob-public-access true
        echo "✅ Enabled public blob access (drift introduced)"
        ;;
      2)
        echo "Adding SSH rule to NSG..."
        NSG_NAME=$(az network nsg list -g $RG_NAME --query "[0].name" -o tsv)
        az network nsg rule create \
          --resource-group $RG_NAME \
          --nsg-name $NSG_NAME \
          --name AllowSSH \
          --priority 200 \
          --source-address-prefixes '*' \
          --destination-port-ranges 22 \
          --access Allow \
          --protocol Tcp
        echo "✅ SSH rule added (drift introduced)"
        ;;
      3)
        echo "Disabling Key Vault soft delete..."
        KV_NAME=$(az keyvault list -g $RG_NAME --query "[0].name" -o tsv)
        echo "⚠️  Soft delete cannot be disabled once enabled (Azure policy)"
        echo "   Instead, changing retention period..."
        az keyvault update \
          --name $KV_NAME \
          --resource-group $RG_NAME \
          --retention-days 7
        echo "✅ Soft delete retention changed from 90 to 7 days (drift introduced)"
        ;;
      4)
        echo "Changing Storage SKU..."
        STORAGE_NAME=$(az storage account list -g $RG_NAME --query "[0].name" -o tsv)
        az storage account update \
          --name $STORAGE_NAME \
          --resource-group $RG_NAME \
          --sku Standard_GRS
        echo "✅ Storage SKU changed to Standard_GRS (drift introduced)"
        ;;
    esac
    ;;
    
  3)
    echo ""
    read -p "Enter resource group name: " RG_NAME
    
    echo "🔍 Generating drift report..."
    echo ""
    
    OUTPUT_DIR="$REPO_ROOT/drift-reports"
    mkdir -p "$OUTPUT_DIR"
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    
    echo "Exporting deployed resources..."
    az group export \
      --name $RG_NAME \
      --output json > "$OUTPUT_DIR/deployed-$TIMESTAMP.json"
    
    echo "Listing resource changes since last deployment..."
    az deployment group list \
      --resource-group $RG_NAME \
      --query "[].{Name:name, Timestamp:properties.timestamp, State:properties.provisioningState}" \
      --output table
    
    echo ""
    echo "✅ Drift report generated: $OUTPUT_DIR/deployed-$TIMESTAMP.json"
    echo ""
    echo "To compare with IaC definitions:"
    echo "1. Build expected state from Bicep templates"
    echo "2. Compare deployed-$TIMESTAMP.json with expected ARM output"
    echo "3. Identify configuration differences"
    ;;
    
  4)
    echo ""
    read -p "Enter resource group name: " RG_NAME
    
    echo "📋 Resources in $RG_NAME:"
    echo ""
    az resource list \
      --resource-group $RG_NAME \
      --query "[].{Name:name, Type:type, Location:location}" \
      --output table
    ;;
    
  5)
    echo ""
    read -p "Enter resource group name: " RG_NAME
    
    OUTPUT_DIR="$REPO_ROOT/exports"
    mkdir -p "$OUTPUT_DIR"
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    EXPORT_FILE="$OUTPUT_DIR/export-$TIMESTAMP.json"
    
    echo "📤 Exporting ARM template..."
    az group export \
      --name $RG_NAME \
      --output json > "$EXPORT_FILE"
    
    echo "✅ Exported to: $EXPORT_FILE"
    
    # Optionally decompile to Bicep
    read -p "Convert to Bicep? (y/n): " CONVERT
    if [[ $CONVERT == "y" || $CONVERT == "Y" ]]; then
      BICEP_FILE="$OUTPUT_DIR/export-$TIMESTAMP.bicep"
      az bicep decompile --file "$EXPORT_FILE" --outfile "$BICEP_FILE"
      echo "✅ Decompiled to: $BICEP_FILE"
    fi
    ;;
    
  6)
    echo ""
    echo "⚠️  This will delete resource groups matching 'rg-drift-test*'"
    echo ""
    az group list --query "[?starts_with(name, 'rg-drift-test')].name" -o table
    echo ""
    read -p "Continue with deletion? (yes/no): " CONFIRM
    
    if [[ $CONFIRM == "yes" ]]; then
      echo "🗑️  Deleting resource groups..."
      az group list --query "[?starts_with(name, 'rg-drift-test')].name" -o tsv | \
        xargs -I {} sh -c 'echo "Deleting {}..." && az group delete --name {} --yes --no-wait'
      echo "✅ Deletion initiated (running in background)"
    else
      echo "Cancelled"
    fi
    ;;
    
  *)
    echo "Invalid choice"
    exit 1
    ;;
esac

echo ""
