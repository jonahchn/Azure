$workspaceId = "/subscriptions/$subscriptionId/resourcegroups/$rgname/providers/microsoft.operationalinsights/workspaces/$workspace"

# Define the log categories for Blob service
$blobLogCategories = @(
    "StorageRead",
    "StorageWrite",
    "StorageDelete"
)

# Get all subscriptions
$subscriptions = Get-AzSubscription

foreach ($sub in $subscriptions) {
    # Set the current subscription
    Set-AzContext -SubscriptionId $sub.Id | Out-Null
    Write-Host "`nChecking Subscription: $($sub.Name) [$($sub.Id)]" -ForegroundColor Cyan

# Get all Storage Accounts in the subscription
$storageAccounts = Get-AzStorageAccount #-ResourceGroupName "networkwatcherrg" -Name "sbansgflowlogs"

foreach ($storageAccount in $storageAccounts) {
    $resourceGroupName = $storageAccount.ResourceGroupName
    $storageName       = $storageAccount.StorageAccountName
    $diagSettingsName  = "Security Logs"

    # Build the Blob service resource ID
    $blobResourceId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageName/blobServices/default"

    Write-Output "Configuring diagnostic settings for Blob service in Storage Account: $storageName"

    # Build log settings as hashtables
    $logSettings = @()
    foreach ($logCategory in $blobLogCategories) {
        $logSettings += @{
            Category = $logCategory
            Enabled  = $true
        }
    }

    # Apply diagnostic settings to the Blob service
    New-AzDiagnosticSetting `
        -Name $diagSettingsName `
        -ResourceId $blobResourceId `
        -WorkspaceId $workspaceId `
        -Log $logSettings `
        -ErrorAction SilentlyContinue

    Write-Output "Diagnostic settings enabled successfully for Blob service in $storageName"
}

Write-Output "Completed configuration for Blob service diagnostic settings for Storage Accounts in $($sub.Name)"
}
