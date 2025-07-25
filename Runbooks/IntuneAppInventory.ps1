# === Get secrets from automation variables ===
$global:tenantId = Get-AutomationVariable -Name 'tenantId'
$global:clientId = Get-AutomationVariable -Name 'clientId'
$global:clientSecret = Get-AutomationVariable -Name 'ClientSecret'
$resourceGroup = Get-AutomationVariable -Name 'resourceGroup'
$storageAccountName = Get-AutomationVariable -Name 'storageAccountName'
$storageAccountKey = Get-AutomationVariable -Name 'StorageAccountKey'
$tableName = "IntuneAppInventory"
$automationAccountName = Get-AutomationVariable -Name 'automationAccountName'
$runbookName = "IntuneAppInventory"
$runbookRG = Get-AutomationVariable -Name 'runbookRG'

# Connect to Azure with system-assigned managed identity
Connect-AzAccount -Identity

# Get storage context
$ctx = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

# === Check if first run ===
$nextLink = Get-AutomationVariable -Name 'DetectedAppsNextLink'
$firstRun = [string]::IsNullOrWhiteSpace($nextLink)

# Delete + recreate table only on first run
$table = Get-AzStorageTable –Name $tableName –Context $ctx -ErrorAction SilentlyContinue
if ($firstRun) {
    if ($table) {
        Write-Host "Deleting existing table: $tableName"
        $table.CloudTable.Delete()
        Start-Sleep -Seconds 60
    }

    Write-Host "Creating table: $tableName"
    $table = New-AzStorageTable -Name $tableName -Context $ctx
    Set-AutomationVariable -Name 'DetectedAppsNextLink' -Value ""
}

# === Token Handling ===
# Function to get a fresh access token
function Get-GraphAccessToken {
    $body = @{
        client_id     = $global:clientId
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $global:clientSecret
        grant_type    = "client_credentials"
    }
    $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$global:tenantId/oauth2/v2.0/token" -Body $body
    return @{ token = $response.access_token; timestamp = Get-Date }
}

$auth = Get-GraphAccessToken
$global:accessToken = $auth.token
$global:tokenIssuedAt = $auth.timestamp

# Function to refresh token if older than 55 minutes
function Refresh-TokenIfNeeded {
    $now = Get-Date
    $elapsed = ($now - $global:tokenIssuedAt).TotalMinutes
    if ($elapsed -ge 55) {
        Write-Output "Access token expired after $([int]$elapsed) minutes. Refreshing..."
        $auth = Get-GraphAccessToken -TenantId $global:tenantId -ClientId $global:clientId -ClientSecret $global:clientSecret
        
        if (-not $auth.token) {
            throw "Failed to get new access token"
        }

        $global:accessToken = $auth.token
        $global:tokenIssuedAt = $auth.timestamp
        Write-Host "Token refreshed successfully at $($global:tokenIssuedAt)"
    } #else {        Write-Host "Token still valid."    }
}

# Function to make a GET request to Graph with auto-refresh
function Invoke-GraphGet {
    param ([string]$Uri)

    Refresh-TokenIfNeeded

    $headers = @{ Authorization = "Bearer $global:accessToken" }

    $maxRetries = 5
    $retryCount = 0
   
    while ($retryCount -lt $maxRetries) {
        try{
            return (Invoke-RestMethod -Uri $Uri -Headers $headers -Method Get)
        } catch {
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode.Value__ -eq 429) {
                $retryAfter = $_.Exception.Response.Headers["Retry-After"]
                if (-not $retryAfter) {
                    $retryAfter = 10
                }

                Write-Warning "Hit rate limit (429). Retrying in $retryAfter seconds..."
                Start-Sleep -Seconds ([int]$retryAfter)
                $retryCount++
            } else {
                Write-Error "Graph API call failed: $($_.Exception.Message)"
                throw $_
            }
        }
    }

    throw "Exceeded maximum retry attempts for $Uri"
}

function Get-NextLink {
    $uri = Get-AutomationVariable -Name 'DetectedAppsNextLink'
    if (-not $uri) {
        $uri = 'https://graph.microsoft.com/v1.0/deviceManagement/detectedApps?$top=500'
    }
    return $uri
}

function Set-NextLink ($nextLink) {
    if ($null -ne $nextLink -and [string]::IsNullOrWhiteSpace([string]$nextLink) -eq $false) {
        Set-AutomationVariable -Name 'DetectedAppsNextLink' -Value $nextLink
    } else {
        Set-AutomationVariable -Name 'DetectedAppsNextLink' -Value ""
    }
}

# === Main Logic ===
$uri = Get-NextLink
$appsProcessed = 0

    $detectedAppValues = Invoke-GraphGet $uri

    foreach ($detectedAppValue in $detectedAppValues.value) {
        $id = $detectedAppValue.id
        $appDevices = Invoke-GraphGet "https://graph.microsoft.com/v1.0/deviceManagement/detectedApps/$id/managedDevices"
        if (-not $appDevices) {
            Write-Warning "Skipping app $id"
            continue
        }
        
        foreach ($appDevice in $appDevices.value) {
            $partitionKey = "DefaultPartitionKey"
            $rowKey       = [guid]::NewGuid().ToString()
            $properties   = @{  
                        AppId        = $detectedAppValue.id
                        AppName      = $detectedAppValue.displayName
                        AppVersion   = $detectedAppValue.version
                        AppPublisher = $detectedAppValue.publisher
                        AppPlatform  = $detectedAppValue.platform
                        DeviceName   = $appDevice.deviceName
                        UserEmail    = $appDevice.emailAddress
                        OS           = $appDevice.operatingSystem
                        }

    #Debug: Check for null values
    if (-not $table.CloudTable){throw "cloudtable is null"}
    if (-not $partitionKey -or -not $rowKey){throw "partion or row key is null"}
    foreach ($key in $properties.Keys) {
        if ($null -eq $properties[$key]) {
            Write-Warning "Property '$key' is null"
            $properties[$key] = "" 
            }
         }

            #Upload App Inventory to Azure Table
            Add-AzTableRow -table $table.CloudTable -partitionKey $partitionKey -rowKey $rowKey -property $properties | Out-Null
    
            #Get last 5 digits of token to verifiy token refresh
            #Write-Output $global:accessToken.Substring($global:accessToken.Length - 5)
    
            #Delay to avoid rate limits
            Start-Sleep -Milliseconds 500
    
        }
        $appsProcessed++
    }

    $nexturi = $detectedAppValues."@odata.nextLink"
    Set-NextLink $nexturi
    Write-Output "Setting Next Link: $nexturi"
    Start-Sleep -Seconds 1

    if ($nexturi) {
        Write-Host "More pages remain. Scheduling next run..."
        Start-AzAutomationRunbook `
            -AutomationAccountName $automationAccountName `
            -Name $runbookName `
            -ResourceGroupName $runbookRG
        break
    }

if (-not $nexturi) {
    Write-Host "All apps processed. Table complete."
    Set-NextLink ""
}

Write-Host "Upload complete. Processed $appsProcessed apps."
