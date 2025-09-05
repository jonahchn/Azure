$workspaceId = "/subscriptions/$subscriptionId/resourcegroups/$rgname/providers/microsoft.operationalinsights/workspaces/$workspace"

# Define the log categories to enable
$logCategories = @("AppServiceIPSecAuditLogs", "AppServiceAuditLogs")#, "AppServiceReportAntivirusAuditLogs")

# Get all Web Apps in the subscription
$webApps = Get-AzWebApp | Where-Object { $_.Kind -eq "app" }

foreach ($webApp in $webApps) {
    $resourceGroupName = $webApp.ResourceGroup
    $webAppName = $webApp.Name
    $resourceId = $webApp.Id
    $diagSettingsName = "App Service Security Logs"

    Write-Output "Configuring diagnostic settings for Web App: $webAppName"

        # Create log settings objects
    $logSettings = @()
    foreach ($logCategory in $logCategories) {
        $logSettings += New-Object Microsoft.Azure.PowerShell.Cmdlets.Monitor.DiagnosticSetting.Models.Api20210501Preview.LogSettings -Property @{
            Category = $logCategory
            Enabled  = $true
        }
    } 

    # Enable diagnostic settings
    New-AzDiagnosticSetting -Name $diagSettingsName -ResourceId $resourceId -WorkspaceId $workspaceId -Log $logSettings


    Write-Output "Diagnostic settings enabled successfully for $webAppName"
}

Write-Output "Completed configuration for all Web Apps in the subscription."


