using './keyvault_template.bicep'

param vaultName = 'mykv-prod-001'
param location = 'westeurope'
param enabledForDeployment = true
param enabledForTemplateDeployment = true
