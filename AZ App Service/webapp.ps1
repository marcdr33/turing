$resourceGroup = "rg-turing-poc-spc"
$location = "spaincentral"
$appServicePlan = "asp-turing-poc-spc"
$webApp = "app-turing-poc-spc"

az appservice plan create `
  --name $appServicePlan `
  --resource-group $resourceGroup `
  --location $location `
  --sku FREE `
  --is-linux

az webapp create `
  --name $webApp `
  --resource-group $resourceGroup `
  --plan $appServicePlan `
  --runtime "PYTHON:3.11"