# This runbook attempts to enable Encryption-At-Host on Azure VMs and is triggered by a webhook

param (
    [Parameter(Mandatory=$false)]
    [object] $WebhookData
)

# Authenticate using Managed Identity
Connect-AzAccount -Identity

# Parse the incoming Event Grid payload
$resourceId = $WebhookData.RequestBody 

# Extract the resource group and VM name from the resourceId
if ($resourceId -match "/subscriptions/.+/resourceGroups/(?<rg>[^/]+)/providers/Microsoft.Compute/virtualMachines/(?<vm>[^/]+)") {
    $resourceGroupName = $matches['rg']
    $vmName = $matches['vm']
    Write-Output "Detected VM: $vmName in Resource Group: $resourceGroupName"
} else {
    Write-Output "Could not extract VM info from resourceId: $resourceId"
    return
}

# Get the VM object
$vm = Get-AzVM -Name $vmName -ResourceGroupName $resourceGroupName

# Check if encryptionathost is enabled
#if ($vm.SecurityProfile -and $vm.SecurityProfile.EncryptionAtHost -eq $true) {
#    Write-Output "EncryptionAtHost is already enabled for VM '$vmName'. Exiting"
#    exit
#} else {
#    Write-Output "Encryption at host is NOT enabled for VM: $vmName"
#    return
#}

# Enable encryption at host
$vm.SecurityProfile = @{ encryptionAtHost = $true }

# Apply the change
Update-AzVM -VM $vm -ResourceGroupName $resourceGroupName

Write-Output "Encryption at host has been enabled for VM: $vmName"
