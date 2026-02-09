@description('Name of the Key Vault')
param vaultName string

@description('Azure region')
param location string = resourceGroup().location

@description('Tenant ID')
param tenantId string = tenant().tenantId

param enabledForDeployment bool = true
param enabledForTemplateDeployment bool = true

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
  }
}

output vaultUri string = keyVault.properties.vaultUri
