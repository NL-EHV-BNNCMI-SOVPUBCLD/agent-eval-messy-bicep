# Deployment Workflows

This repository contains intentionally chaotic Bicep templates for testing drift detection tools. The workflows deploy resources using various parameter file formats and locations.

## Prerequisites

### 1. Azure Service Principal (Federated Credentials - OIDC)

Create an Azure AD App Registration with federated credentials for GitHub Actions:

```bash
# Create Resource Group for testing
az group create --name rg-drift-test-shared --location westeurope

# Create Service Principal with Contributor role
az ad sp create-for-rbac \
  --name "sp-drift-test-github" \
  --role contributor \
  --scopes /subscriptions/{SUBSCRIPTION_ID}/resourceGroups/rg-drift-test-shared \
  --sdk-auth

# Add federated credential for GitHub Actions
az ad app federated-credential create \
  --id {APP_ID} \
  --parameters '{
    "name": "github-drift-test",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:NL-EHV-BNNCMI-SOVPUBCLD/agent-eval-messy-bicep:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### 2. GitHub Repository Secrets

Add these secrets to your repository (`Settings` → `Secrets and variables` → `Actions`):

| Secret Name | Description | How to Get |
|------------|-------------|------------|
| `AZURE_CLIENT_ID` | Application (client) ID | From Azure AD App Registration |
| `AZURE_TENANT_ID` | Directory (tenant) ID | From Azure AD App Registration |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID | `az account show --query id -o tsv` |

### 3. GitHub Environments (Optional)

Create environments for approval gates:
- `dev` (no approvals)
- `staging` (optional approvals)
- `prod` (required approvals)

## Available Workflows

### 1. **Deploy Infrastructure** ([deploy-infrastructure.yml](.github/workflows/deploy-infrastructure.yml))
Deploys core networking and storage resources.

**Resources:**
- Virtual Network (using JSON params)
- Network Security Group (using bicepparam)
- Storage Account (using JSON params from `temp/` folder)
- Key Vault (using bicepparam from `random/stuff/`)

**Usage:**
```bash
# Trigger via GitHub UI: Actions → Deploy Infrastructure → Run workflow
# Or via GitHub CLI:
gh workflow run deploy-infrastructure.yml \
  -f environment=dev \
  -f resource_group=rg-drift-test-dev
```

### 2. **Deploy Applications** ([deploy-applications.yml](.github/workflows/deploy-applications.yml))
Deploys application-tier resources.

**Resources:**
- Azure Container Registry (using bicepparam from `p/`)
- Web App + App Service Plan (using bicepparam)
- Application Insights (optional, using JSON params from `a/b/c/`)

**Usage:**
```bash
gh workflow run deploy-applications.yml \
  -f environment=dev \
  -f resource_group=rg-drift-test-dev \
  -f log_analytics_workspace_id=/subscriptions/{SUB}/resourceGroups/{RG}/providers/Microsoft.OperationalInsights/workspaces/{WORKSPACE}
```

### 3. **Deploy Databases** ([deploy-databases.yml](.github/workflows/deploy-databases.yml))
Deploys database resources individually.

**Resources:**
- Cosmos DB (from `backup/old/` using `test/` params)
- SQL Database (from `misc/database/` using `PROD_PARAMS/`)

**Usage:**
```bash
gh workflow run deploy-databases.yml \
  -f environment=dev \
  -f resource_group=rg-drift-test-dev \
  -f deploy_cosmos=true \
  -f deploy_sql=true
```

### 4. **VM Deployment** ([vm-deploy.yml](.github/workflows/vm-deploy.yml))
Deploys virtual machine (requires existing NIC).

**Resources:**
- Virtual Machine (from `modules/` using `deploy/staging/` params)

**Prerequisites:** Network Interface must exist first.

**Usage:**
```bash
# Create NIC first
az network nic create \
  --name vm-nic-01 \
  --resource-group rg-drift-test-dev \
  --vnet-name myVNet \
  --subnet subnet1

# Deploy VM
gh workflow run vm-deploy.yml \
  -f resource_group=rg-drift-test-dev \
  -f nic_id=/subscriptions/{SUB}/resourceGroups/{RG}/providers/Microsoft.Network/networkInterfaces/vm-nic-01
```

### 5. **Full Stack Deployment** ([full-stack-deploy.yml](.github/workflows/full-stack-deploy.yml))
Orchestrated deployment of core infrastructure + applications.

**Resources:** Storage, NSG, VNet, ACR, Web App, Key Vault

**Usage:**
```bash
gh workflow run full-stack-deploy.yml \
  -f environment=dev \
  -f resource_group_prefix=rg-drift-test
```

## Drift Testing Scenarios

### Scenario 1: Manual Configuration Changes
1. Deploy using workflows
2. Manually modify resources via Azure Portal
3. Run drift detection to identify changes

### Scenario 2: Parameter File Updates
1. Deploy with initial parameters
2. Update parameter files (e.g., change SKU in `storage-params.json`)
3. Redeploy and detect configuration drift

### Scenario 3: API Version Drift
1. Deploy resources
2. Update API versions in Bicep templates
3. Compare deployed resources against new template definitions

### Scenario 4: Missing Resources
1. Deploy full stack
2. Manually delete resources via Portal
3. Detect missing resources that should exist

## Parameter File Mapping

| Template | Parameter File | Format | Location |
|----------|---------------|--------|----------|
| `storage.bicep` | `temp/params/storage-params.json` | JSON | Temp folder |
| `nsg_rules.bicep` | `configs/nsg-config.bicepparam` | Bicep Params | Configs folder |
| `ContainerRegistry.bicep` | `p/acr-prod.bicepparam` | Bicep Params | Single letter folder |
| `webapp/app.bicep` | `webapp/dev-params.bicepparam` | Bicep Params | Same folder |
| `old_stuff/network/vnet.bicep` | `parameters.json` | JSON | Root |
| `random/stuff/keyvault_template.bicep` | `random/stuff/kv.bicepparam` | Bicep Params | Same folder |
| `backup/old/cosmos.bicep` | `test/cosmos-test.json` | JSON | Test folder |
| `misc/database/sqldb.bicep` | `PROD_PARAMS/sql.parameters.json` | JSON | Prod params folder |
| `randomfolder/appinsights.bicep` | `a/b/c/insights-params.json` | JSON | Deep nested |
| `modules/vm_thing.bicep` | `deploy/staging/vm.parameters.json` | JSON | Deploy folder |

## Clean Up

```bash
# Delete resource group
az group delete --name rg-drift-test-dev --yes --no-wait

# List all drift test resource groups
az group list --query "[?tags.ManagedBy=='GitHub'].name" -o table

# Delete all drift test resource groups
az group list --query "[?tags.ManagedBy=='GitHub'].name" -o tsv | \
  xargs -I {} az group delete --name {} --yes --no-wait
```

## Intentional Chaos Features

This repository intentionally includes:
- ✅ Mixed parameter formats (JSON + Bicep params)
- ✅ Scattered file locations across 10+ directories
- ✅ Inconsistent naming conventions
- ✅ Environment mismatches (prod params for dev deployments)
- ✅ Orphaned parameter files
- ✅ Non-standard folder structures
- ✅ Mix of old and new API versions

**Perfect for testing drift detection resilience!**
