#Connect-AzAccount

$subscription = ""
$resourceGroup = ""

$token = (Get-AzAccessToken -ResourceUrl 'https://management.azure.com').Token

$getmachines = Get-AzConnectedMachine -ResourceGroupName $resourceGroup
$machines=$getmachines.Name

foreach ($machines in $machines){

$url = "https://management.azure.com/subscriptions/$subscription/resourceGroups/$resourceGroup/providers/Microsoft.HybridCompute/machines/$machines/providers/Microsoft.Security/pricings/virtualMachines?api-version=2024-01-01"

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json" 

}

$price = @{pricingTier = "Free"}
$prop = @{properties = $price}
$Body = $prop | ConvertTo-Json

$request = Invoke-RestMethod -Method 'Put' -Uri $url -Headers $headers -Body $Body
#$request = Invoke-RestMethod -Method 'Get' -Uri $url -Headers $headers 

$request.id
$request.properties.pricingTier
}


