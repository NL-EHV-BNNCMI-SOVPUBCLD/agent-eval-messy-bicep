param vnetName string
param location string = resourceGroup().location
param addressPrefix string = '10.0.0.0/16'

param subnets array = [
  {
    name: 'default'
    addressPrefix: '10.0.0.0/24'
  }
]

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
      }
    }]
  }
}

output vnetId string = virtualNetwork.id
output subnets array = virtualNetwork.properties.subnets
