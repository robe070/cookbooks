# Requires: $env:AZURE_TENANT_ID, $env:AZURE_CLIENT_ID, $env:AZURE_CLIENT_SECRET, $env:AZURE_LOCATION

$ErrorActionPreference = 'Stop'

# --- Validate required environment variables ---
foreach ($var in 'AZURE_TENANT_ID','AZURE_CLIENT_ID','AZURE_CLIENT_SECRET','AZURE_LOCATION') {
    if (-not (Get-Item "env:$var" -ErrorAction SilentlyContinue) -or
        [string]::IsNullOrWhiteSpace((Get-Item "env:$var").Value)) {
        Write-Error "Required environment variable '$var' is not set."
        return
    }
}

Write-Host
'Troubleshooting tips for the customer environment
1. TLS errors on older Windows PowerShell 5.1: prepend [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
2. Proxy issues: add -Proxy $env:HTTPS_PROXY -ProxyUseDefaultCredentials to both Invoke-RestMethod calls.
3. Inspect raw HTTP response: swap Invoke-RestMethod for Invoke-WebRequest and print .StatusCode, .Headers, and .Content.
4. AADSTS errors (invalid_client, unauthorized_client) come back in the response body — the catch block prints $_.ErrorDetails.Message, which contains the AAD JSON error code/description.
5. Permission issue when listing subscriptions: the service principal needs at least the Reader role on the subscription, otherwise value comes back as an empty array.
6. Multiple subscriptions returned: the C++ code requires exactly one — scope the service principal to a single subscription, or filter on subscriptionId before this check.'

# --- 1. Request an Azure ARM access token (client credentials flow) ---
$tokenUri = "https://login.microsoftonline.com/$($env:AZURE_TENANT_ID)/oauth2/v2.0/token"
$tokenBody = @{
    grant_type    = 'client_credentials'
    client_id     = $env:AZURE_CLIENT_ID
    client_secret = $env:AZURE_CLIENT_SECRET
    scope         = 'https://management.azure.com/.default'
}

Write-Host "Requesting Azure ARM access token..."
try {
    $tokenResponse = Invoke-RestMethod `
        -Method Post `
        -Uri $tokenUri `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body $tokenBody
} catch {
    Write-Error "Azure ARM token request failed: $($_.Exception.Message)"
    if ($_.ErrorDetails) { Write-Error "Response body: $($_.ErrorDetails.Message)" }
    return
}

if (-not $tokenResponse) {
    Write-Error "Azure ARM token response was not a JSON object."
    return
}

$accessToken = $tokenResponse.access_token
if ([string]::IsNullOrEmpty($accessToken)) {
    Write-Error "Azure ARM token response did not contain access_token (or it was empty)."
    return
}
Write-Host "Access token acquired."

# --- 2. List subscriptions visible to the service principal ---
$subsUri = 'https://management.azure.com/subscriptions?api-version=2022-12-01'
$authHeaders = @{ Authorization = "Bearer $accessToken" }

Write-Host "Requesting Azure ARM subscriptions..."
try {
    $subsResponse = Invoke-RestMethod -Method Get -Uri $subsUri -Headers $authHeaders
} catch {
    Write-Error "Azure ARM subscriptions request failed: $($_.Exception.Message)"
    if ($_.ErrorDetails) { Write-Error "Response body: $($_.ErrorDetails.Message)" }
    return
}

if (-not $subsResponse) {
    Write-Error "Azure ARM subscriptions response was not a JSON object."
    return
}

$subscriptions = $subsResponse.value
if ($null -eq $subscriptions -or $subscriptions -isnot [System.Array]) {
    # Single-element responses may not deserialize as an array; coerce.
    if ($null -ne $subscriptions) {
        $subscriptions = @($subscriptions)
    } else {
        Write-Error "Azure ARM subscriptions response did not contain a value array."
        return
    }
}

if ($subscriptions.Count -eq 0) {
    Write-Error "Azure ARM subscriptions response did not contain any subscriptions."
    return
}

if ($subscriptions.Count -ne 1) {
    Write-Error "Azure ARM cloud licensing requires credentials scoped to exactly one subscription (found $($subscriptions.Count))."
    return
}

$subscription = $subscriptions[0]
if (-not $subscription -or -not $subscription.subscriptionId) {
    Write-Error "Azure ARM subscriptions response did not contain subscriptionId."
    return
}

$subscriptionId = $subscription.subscriptionId
$location       = $env:AZURE_LOCATION

# --- 3. Build the normalized identity document ---
$identityDocument = [pscustomobject]@{
    compute = [pscustomobject]@{
        subscriptionId = $subscriptionId
        location       = $location
    }
} | ConvertTo-Json -Compress -Depth 5

Write-Host ""
Write-Host "Subscription ID  : $subscriptionId"
Write-Host "Location         : $location"
Write-Host "Identity document:"
Write-Host $identityDocument

# Make values available to the caller
$global:AzureSubscriptionId   = $subscriptionId
$global:AzureIdentityDocument = $identityDocument