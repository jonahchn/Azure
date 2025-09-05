# Get all subscriptions
$subscriptions = Get-AzSubscription

foreach ($sub in $subscriptions) {
    # Set the current subscription
    Set-AzContext -SubscriptionId $sub.Id | Out-Null
    Write-Host "`nChecking Subscription: $($sub.Name) [$($sub.Id)]" -ForegroundColor Cyan

    # Get all storage accounts in the current subscription
    $storageAccounts = Get-AzStorageAccount

    foreach ($account in $storageAccounts) {
        Write-Host "`nStorage Account: $($account.StorageAccountName) in Resource Group: $($account.ResourceGroupName)" -ForegroundColor Yellow
        $ctx = $account.Context

        # Get all containers within the storage account
        $containers = Get-AzStorageContainer -Context $ctx
        foreach ($container in $containers) {
            Write-Host " - Container: $($container.Name) | Public Access: $($container.PublicAccess)" -ForegroundColor Green
        }
    }
}
