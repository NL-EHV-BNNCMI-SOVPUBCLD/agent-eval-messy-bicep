using './keyvault_template.bicep'

param vaultName = 'mykv-prod-001'
param location = 'westus2'
param enabledForDeployment = true
param enabledForTemplateDeployment = true
