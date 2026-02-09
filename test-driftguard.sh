#!/bin/bash
# Test DriftGuard against all deployed resources in the messy bicep repo
# Uses Docker container for consistent execution

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RG_NAME="rg-messydrift-test"
DOCKER_IMAGE="mwhooo/driftguard:latest"

echo "🔍 Testing DriftGuard against deployed resources"
echo "================================================"
echo "Resource Group: $RG_NAME"
echo "Docker Image: $DOCKER_IMAGE"
echo ""

# Check if Azure CLI is logged in
if ! az account show &> /dev/null; then
    echo "❌ Not logged into Azure. Run: az login"
    exit 1
fi

echo "✅ Azure CLI authenticated"
echo ""

# Function to run DriftGuard with Docker
run_drift_check() {
    local name=$1
    local bicep_file=$2
    local params_file=$3
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔍 Checking: $name"
    echo "   Template: $bicep_file"
    if [ -n "$params_file" ]; then
        echo "   Parameters: $params_file"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Create a temporary writable copy of Azure config for the container
    local temp_azure=$(mktemp -d)
    cp -r ~/.azure/* "$temp_azure/" 2>/dev/null || true
    
    if [ -n "$params_file" ]; then
        # Using separate params file
        docker run --rm \
            -v "$temp_azure:/root/.azure" \
            -v "$SCRIPT_DIR:/workspace" \
            "$DOCKER_IMAGE" \
            --bicep-file "/workspace/$bicep_file" \
            --parameters-file "/workspace/$params_file" \
            --resource-group "$RG_NAME" \
            --output Console
    else
        # Using bicepparam file
        docker run --rm \
            -v "$temp_azure:/root/.azure" \
            -v "$SCRIPT_DIR:/workspace" \
            "$DOCKER_IMAGE" \
            --bicep-file "/workspace/$bicep_file" \
            --resource-group "$RG_NAME" \
            --output Console
    fi
    
    # Clean up temp directory
    rm -rf "$temp_azure"
    
    echo ""
    echo ""
}

# Test all deployed resources from full-stack-deploy workflow

echo "📦 TESTING CORE INFRASTRUCTURE"
echo "==============================="
echo ""

# 1. Storage Account
run_drift_check \
    "Storage Account" \
    "storage.bicep" \
    "temp/params/storage-params.json"

# 2. Network Security Group
run_drift_check \
    "Network Security Group" \
    "configs/nsg-config.bicepparam" \
    ""

# 3. Virtual Network
run_drift_check \
    "Virtual Network" \
    "old_stuff/network/vnet.bicep" \
    "parameters.json"

echo "🚀 TESTING APPLICATION TIER"
echo "============================"
echo ""

# 4. Azure Container Registry
run_drift_check \
    "Azure Container Registry" \
    "p/acr-prod.bicepparam" \
    ""

# 5. Web App + App Service Plan
run_drift_check \
    "Web App + App Service Plan" \
    "webapp/dev-params.bicepparam" \
    ""

# 6. Key Vault
run_drift_check \
    "Key Vault" \
    "random/stuff/kv.bicepparam" \
    ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All drift checks complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 To test individual resources:"
echo ""
echo "   # Storage"
echo "   docker run --rm -v ~/.azure:/root/.azure:ro -v \$(pwd):/workspace mwhooo/driftguard \\"
echo "     --bicep-file /workspace/storage.bicep \\"
echo "     --parameters-file /workspace/temp/params/storage-params.json \\"
echo "     --resource-group $RG_NAME"
echo ""
echo "   # NSG (with bicepparam)"
echo "   docker run --rm -v ~/.azure:/root/.azure:ro -v \$(pwd):/workspace mwhooo/driftguard \\"
echo "     --bicep-file /workspace/configs/nsg-config.bicepparam \\"
echo "     --resource-group $RG_NAME"
echo ""
echo "💡 To introduce drift for testing:"
echo "   ./scripts/drift-testing.sh  # Select option 2"
echo ""
