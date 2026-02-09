@minLength(5)
@maxLength(50)
param registryName string

param location string = resourceGroup().location

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Standard'

param adminUserEnabled bool = false

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: registryName
  location: location
  sku: {
    name: skuName
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: 'Enabled'
  }
}

output loginServer string = containerRegistry.properties.loginServer
output registryId string = containerRegistry.id
