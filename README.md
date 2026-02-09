# Agent Eval - Messy Bicep Repository

An **intentionally chaotic** Bicep repository designed for testing Infrastructure-as-Code (IaC) drift detection tools.

## 🎯 Purpose

This repository simulates real-world scenarios where:
- Teams have inconsistent file organization
- Multiple parameter file formats coexist (JSON + Bicep params)
- Files are scattered across non-standard directories
- Environment naming is inconsistent
- Legacy and modern approaches mix

Perfect for validating drift detection tools can handle messy, production-like codebases.

## 📁 Repository Structure

```
├── .github/workflows/          # GitHub Actions deployment workflows
│   ├── deploy-infrastructure.yml
│   ├── deploy-applications.yml
│   ├── deploy-databases.yml
│   ├── vm-deploy.yml
│   └── full-stack-deploy.yml
├── scripts/                    # Helper scripts
│   ├── setup-azure-auth.sh    # Azure authentication setup
│   └── drift-testing.sh       # Drift testing scenarios
├── Bicep Templates (scattered):
│   ├── ContainerRegistry.bicep          # Root level
│   ├── storage.bicep                    # Root level
│   ├── nsg_rules.bicep                  # Root level
│   ├── webapp/app.bicep                 # Webapp folder
│   ├── modules/vm_thing.bicep           # Modules folder
│   ├── backup/old/cosmos.bicep          # Backup/old folder
│   ├── misc/database/sqldb.bicep        # Misc/database folder
│   ├── old_stuff/network/vnet.bicep     # Old stuff folder
│   ├── random/stuff/keyvault_template.bicep
│   └── randomfolder/appinsights.bicep
└── Parameter Files (even more scattered):
    ├── parameters.json                   # Root (VNet params)
    ├── configs/nsg-config.bicepparam
    ├── webapp/dev-params.bicepparam
    ├── p/acr-prod.bicepparam
    ├── random/stuff/kv.bicepparam
    ├── deploy/staging/vm.parameters.json
    ├── PROD_PARAMS/sql.parameters.json
    ├── temp/params/storage-params.json
    ├── test/cosmos-test.json
    └── a/b/c/insights-params.json
```

## 🚀 Quick Start

### 1. Setup Azure Authentication

Run the interactive setup script:

```bash
./scripts/setup-azure-auth.sh
```

This will:
- Create an Azure AD App Registration
- Configure federated credentials for GitHub Actions (OIDC)
- Generate required secrets
- Optionally add secrets to GitHub automatically

**Manual alternative:** See [DEPLOYMENT.md](DEPLOYMENT.md) for manual setup instructions.

### 2. Deploy Resources

**Option A: Via GitHub Actions UI**
1. Go to **Actions** tab in GitHub
2. Select a workflow (e.g., "Full Stack Deployment")
3. Click **Run workflow**
4. Fill in parameters and run

**Option B: Via GitHub CLI**

```bash
# Deploy full stack
gh workflow run full-stack-deploy.yml \
  -f environment=dev \
  -f resource_group_prefix=rg-drift-test

# Deploy infrastructure only
gh workflow run deploy-infrastructure.yml \
  -f environment=dev \
  -f resource_group=rg-drift-test-infra

# Deploy applications
gh workflow run deploy-applications.yml \
  -f environment=dev \
  -f resource_group=rg-drift-test-apps
```

**Option C: Manual deployment with helper script**

```bash
./scripts/drift-testing.sh
# Select option 1: Deploy base infrastructure
```

### 3. Test Drift Detection

```bash
# Introduce drift
./scripts/drift-testing.sh
# Select option 2: Introduce manual drift

# Generate drift report
./scripts/drift-testing.sh
# Select option 3: Generate drift report
```

## 📚 Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Detailed deployment guide, workflow documentation, and drift testing scenarios
- **[scripts/setup-azure-auth.sh](scripts/setup-azure-auth.sh)** - Azure authentication setup
- **[scripts/drift-testing.sh](scripts/drift-testing.sh)** - Interactive drift testing helper

## 🔍 Drift Testing Scenarios

### Scenario 1: Configuration Drift
1. Deploy infrastructure using workflows
2. Manually modify a resource (e.g., change Storage SKU in Portal)
3. Run drift detection to identify the change

### Scenario 2: Missing Resources
1. Deploy full stack
2. Delete a resource via Azure Portal
3. Detect missing resource that should exist per IaC

### Scenario 3: Unauthorized Resources
1. Deploy base infrastructure
2. Manually create additional resources in the RG
3. Detect resources not defined in IaC

### Scenario 4: Parameter File Updates
1. Deploy with current parameters
2. Update parameter file values (don't redeploy)
3. Detect drift between deployed state and IaC definitions

## 🎭 Intentional Chaos Features

This repository deliberately includes:

| Feature | Example | Purpose |
|---------|---------|---------|
| **Mixed parameter formats** | `.bicepparam` + `.json` | Test format compatibility |
| **Scattered files** | 11+ different directories | Test file discovery |
| **Inconsistent naming** | `vm_thing.bicep`, `keyvault_template.bicep` | Test naming pattern detection |
| **Environment mismatches** | `PROD_PARAMS` for dev | Test environment inference |
| **Deep nesting** | `a/b/c/insights-params.json` | Test path resolution |
| **Misleading folders** | `backup/old/`, `temp/` | Test active vs archived detection |
| **API version variations** | 2020 to 2023 versions | Test version drift detection |

## 🧪 Workflows

| Workflow | Trigger | Resources Deployed |
|----------|---------|-------------------|
| **Deploy Infrastructure** | Manual | VNet, NSG, Storage, KeyVault |
| **Deploy Applications** | Manual | ACR, Web App, App Insights |
| **Deploy Databases** | Manual | Cosmos DB, SQL Database |
| **VM Deployment** | Manual | Virtual Machine |
| **Full Stack Deployment** | Manual | Core + Apps (orchestrated) |

All workflows use **OpenID Connect (OIDC)** for secure, keyless Azure authentication.

## 🧹 Cleanup

```bash
# Delete specific resource group
az group delete --name rg-drift-test-dev --yes

# Delete all drift test resource groups
./scripts/drift-testing.sh
# Select option 6: Clean up all test resources

# Clean up Azure AD resources
az ad sp delete --id <CLIENT_ID>
```

## 📊 Resource Coverage

| Azure Resource | Template Location | API Version |
|----------------|------------------|-------------|
| Container Registry | [ContainerRegistry.bicep](ContainerRegistry.bicep) | 2023-07-01 |
| Storage Account | [storage.bicep](storage.bicep) | 2023-01-01 |
| Network Security Group | [nsg_rules.bicep](nsg_rules.bicep) | 2023-05-01 |
| App Service | [webapp/app.bicep](webapp/app.bicep) | 2023-01-01 |
| Virtual Machine | [modules/vm_thing.bicep](modules/vm_thing.bicep) | 2023-09-01 |
| Cosmos DB | [backup/old/cosmos.bicep](backup/old/cosmos.bicep) | 2023-11-15 |
| SQL Database | [misc/database/sqldb.bicep](misc/database/sqldb.bicep) | 2023-05-01-preview |
| Key Vault | [random/stuff/keyvault_template.bicep](random/stuff/keyvault_template.bicep) | 2023-07-01 |
| Virtual Network | [old_stuff/network/vnet.bicep](old_stuff/network/vnet.bicep) | 2023-05-01 |
| Application Insights | [randomfolder/appinsights.bicep](randomfolder/appinsights.bicep) | 2020-02-02 |

## 🤝 Contributing

This is a test repository - feel free to add more chaos! Ideas:
- Add duplicate resource definitions
- Create orphaned parameter files
- Mix more API versions
- Add commented-out resources
- Include deprecated properties

## 📝 License

MIT License - This is a test repository for evaluation purposes.

---

**Built with intentional chaos for serious drift detection testing** 🎯
