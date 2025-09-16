# Authentication fails
# Maybe once thats fixed the rest will work?

# === CONFIGURATION ===
$tenantId = "<your-tenant-id>"
$clientId = "<your-client-id>"
$clientSecret = "<your-client-secret>"

$offerId = "<your-offer-id>"           # e.g., "lansa-scalable-license"
$sourcePlanId = "<source-plan-id>"     # e.g., "win-2022-v16"
$newPlanId = "<new-plan-id>"           # e.g., "win-2022-v16-test"

# === AUTHENTICATION ===
$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
    -Body @{
        grant_type    = "client_credentials"
        scope         = "https://api.partnercenter.microsoft.com/.default"
        client_id     = $clientId
        client_secret = $clientSecret
    }

$accessToken = $tokenResponse.access_token
$headers = @{
    Authorization = "Bearer $accessToken"
    "Content-Type" = "application/json"
}

# === GET SOURCE PLAN ===
$baseUri = "https://api.partnercenter.microsoft.com/v1.0/inbound/CommercialMarketplace"
$getUrl = "$baseUri/offer/$offerId/plan/$sourcePlanId"

Write-Host "Retrieving source plan $sourcePlanId..."
$sourcePlan = Invoke-RestMethod -Method GET -Uri $getUrl -Headers $headers

# === MODIFY PLAN ===
$clonedPlan = $sourcePlan.PSObject.Copy()
$clonedPlan.planId = $newPlanId
$clonedPlan.displayName = "$($sourcePlan.displayName) - Clone"
$clonedPlan.name = "$($sourcePlan.name)-clone"
$clonedPlan.id = "$offerId/$newPlanId"

# Optional: tweak pricing, visibility, technical config, etc. here
# $clonedPlan.vmImages[0].sku = "new-sku"

# === PUT NEW PLAN ===
$putUrl = "$baseUri/offer/$offerId/plan/$newPlanId"
$planJson = $clonedPlan | ConvertTo-Json -Depth 10

Write-Host "Creating new plan $newPlanId..."
$response = Invoke-RestMethod -Method PUT -Uri $putUrl -Headers $headers -Body $planJson

Write-Host "`n✅ Plan '$newPlanId' created successfully."
