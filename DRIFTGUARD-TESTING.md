# DriftGuard Testing Guide

Test drift detection against the deployed messy bicep resources.

## 🚀 Quick Start

### Option 1: Test All Resources (Recommended)

```bash
cd /home/mark/code/atos/agent-eval-messy-bicep
./test-driftguard.sh
```

This runs DriftGuard against all 6 deployed resources:
- Storage Account
- Network Security Group
- Virtual Network
- Azure Container Registry
- Web App + App Service Plan
- Key Vault

### Option 2: Test Individual Resources

**Using Docker (Recommended):**

```bash
# Storage Account
docker run --rm \
  -v ~/.azure:/root/.azure:ro \
  -v $(pwd):/workspace \
  mwhooo/driftguard:latest \
  --bicep-file /workspace/storage.bicep \
  --parameters-file /workspace/temp/params/storage-params.json \
  --resource-group rg-messydrift-test

# NSG (using bicepparam)
docker run --rm \
  -v ~/.azure:/root/.azure:ro \
  -v $(pwd):/workspace \
  mwhooo/driftguard:latest \
  --bicep-file /workspace/configs/nsg-config.bicepparam \
  --resource-group rg-messydrift-test

# Virtual Network
docker run --rm \
  -v ~/.azure:/root/.azure:ro \
  -v $(pwd):/workspace \
  mwhooo/driftguard:latest \
  --bicep-file /workspace/old_stuff/network/vnet.bicep \
  --parameters-file /workspace/parameters.json \
  --resource-group rg-messydrift-test

# Azure Container Registry
docker run --rm \
  -v ~/.azure:/root/.azure:ro \
  -v $(pwd):/workspace \
  mwhooo/driftguard:latest \
  --bicep-file /workspace/p/acr-prod.bicepparam \
  --resource-group rg-messydrift-test

# Web App
docker run --rm \
  -v ~/.azure:/root/.azure:ro \
  -v $(pwd):/workspace \
  mwhooo/driftguard:latest \
  --bicep-file /workspace/webapp/dev-params.bicepparam \
  --resource-group rg-messydrift-test

# Key Vault
docker run --rm \
  -v ~/.azure:/root/.azure:ro \
  -v $(pwd):/workspace \
  mwhooo/driftguard:latest \
  --bicep-file /workspace/random/stuff/kv.bicepparam \
  --resource-group rg-messydrift-test
```

**Using .NET Locally:**

```bash
cd /home/mark/code/private/DriftGuard

# Storage
dotnet run -- \
  --bicep-file ../atos/agent-eval-messy-bicep/storage.bicep \
  --parameters-file ../atos/agent-eval-messy-bicep/temp/params/storage-params.json \
  --resource-group rg-messydrift-test

# NSG
dotnet run -- \
  --bicep-file ../atos/agent-eval-messy-bicep/configs/nsg-config.bicepparam \
  --resource-group rg-messydrift-test
```

## 🧪 Testing Drift Scenarios

### 1. Deploy Resources First

Run the GitHub Actions workflow:
```bash
gh workflow run full-stack-deploy.yml
gh run watch
```

Or manually deploy:
```bash
./scripts/drift-testing.sh
# Select option 1: Deploy baseline infrastructure
```

### 2. Verify No Drift (Baseline)

```bash
./test-driftguard.sh
```

Expected output: ✅ No drift detected for all resources

### 3. Introduce Drift

Modify a resource manually:
```bash
./scripts/drift-testing.sh
# Select option 2: Introduce manual drift
# Choose a drift type (e.g., change Storage SKU)
```

Or manually via Azure CLI:
```bash
# Change Storage Account SKU
az storage account update \
  --name bettystoragemessy001 \
  --resource-group rg-messydrift-test \
  --sku Standard_LRS

# Add NSG rule
az network nsg rule create \
  --resource-group rg-messydrift-test \
  --nsg-name nsg-web-tier \
  --name AllowSSH \
  --priority 200 \
  --source-address-prefixes '*' \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp
```

### 4. Detect Drift

```bash
./test-driftguard.sh
```

Expected output: ⚠️ Configuration drift detected!

### 5. Review Filtered Drifts

See what Azure platform changes were ignored:
```bash
docker run --rm \
  -v ~/.azure:/root/.azure:ro \
  -v $(pwd):/workspace \
  mwhooo/driftguard:latest \
  --bicep-file /workspace/storage.bicep \
  --parameters-file /workspace/temp/params/storage-params.json \
  --resource-group rg-messydrift-test \
  --show-filtered
```

### 6. Auto-Fix Drift (Optional)

```bash
docker run --rm \
  -v ~/.azure:/root/.azure:ro \
  -v $(pwd):/workspace \
  mwhooo/driftguard:latest \
  --bicep-file /workspace/storage.bicep \
  --parameters-file /workspace/temp/params/storage-params.json \
  --resource-group rg-messydrift-test \
  --autofix
```

## 📊 Output Formats

### JSON Output (for automation)
```bash
docker run --rm \
  -v ~/.azure:/root/.azure:ro \
  -v $(pwd):/workspace \
  mwhooo/driftguard:latest \
  --bicep-file /workspace/storage.bicep \
  --parameters-file /workspace/temp/params/storage-params.json \
  --resource-group rg-messydrift-test \
  --output Json > drift-report.json
```

### HTML Report
```bash
docker run --rm \
  -v ~/.azure:/root/.azure:ro \
  -v $(pwd):/workspace \
  mwhooo/driftguard:latest \
  --bicep-file /workspace/storage.bicep \
  --parameters-file /workspace/temp/params/storage-params.json \
  --resource-group rg-messydrift-test \
  --output Html > drift-report.html
```

### Markdown Report
```bash
docker run --rm \
  -v ~/.azure:/root/.azure:ro \
  -v $(pwd):/workspace \
  mwhooo/driftguard:latest \
  --bicep-file /workspace/storage.bicep \
  --parameters-file /workspace/temp/params/storage-params.json \
  --resource-group rg-messydrift-test \
  --output Markdown > drift-report.md
```

## 🔧 Advanced Options

### Custom Ignore Configuration

Create a custom ignore config to suppress specific drifts:

```bash
# Create custom-ignore.json
cat > custom-ignore.json << 'EOF'
{
  "globalIgnorePatterns": [
    "id",
    "properties.provisioningState",
    "properties.createdTime",
    "properties.changedTime"
  ],
  "resourceTypeIgnores": {
    "Microsoft.Storage/storageAccounts": [
      "properties.primaryEndpoints.*",
      "properties.networkAcls.defaultAction"
    ]
  }
}
EOF

# Use custom config
docker run --rm \
  -v ~/.azure:/root/.azure:ro \
  -v $(pwd):/workspace \
  mwhooo/driftguard:latest \
  --bicep-file /workspace/storage.bicep \
  --parameters-file /workspace/temp/params/storage-params.json \
  --resource-group rg-messydrift-test \
  --ignore-config /workspace/custom-ignore.json
```

### Simple Output (for CI/CD)

Use ASCII characters instead of Unicode:
```bash
docker run --rm \
  -v ~/.azure:/root/.azure:ro \
  -v $(pwd):/workspace \
  mwhooo/driftguard:latest \
  --bicep-file /workspace/storage.bicep \
  --parameters-file /workspace/temp/params/storage-params.json \
  --resource-group rg-messydrift-test \
  --simple-output
```

## 🐛 Troubleshooting

### Azure CLI Not Authenticated
```bash
az login
az account show  # Verify subscription
```

### Docker Permission Issues
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### Resource Not Found
```bash
# Check if resources are deployed
az resource list --resource-group rg-messydrift-test --output table

# Verify resource group exists
az group show --name rg-messydrift-test
```

### Template Validation Errors
```bash
# Test Bicep compilation locally
az bicep build --file storage.bicep

# Validate deployment
az deployment group validate \
  --resource-group rg-messydrift-test \
  --template-file storage.bicep \
  --parameters temp/params/storage-params.json
```

## 📝 Expected Test Results

After **initial deployment** (no drift):
- All checks should show: ✅ **No configuration drift detected**

After **manual changes** (drift introduced):
- Modified resource should show: ⚠️ **Configuration drift detected**
- Unchanged resources should still show: ✅ **No drift**

After **autofix**:
- All checks should return to: ✅ **No configuration drift detected**

## 🔄 Testing Workflow Integration

The messy bicep repo is perfect for testing DriftGuard because:
- ✅ Multiple resource types across 10+ templates
- ✅ Mixed parameter formats (`.bicepparam` + `.json`)
- ✅ Scattered file locations (tests path resolution)
- ✅ Real-world chaos (various naming patterns)

This validates DriftGuard handles complex, production-like scenarios!
