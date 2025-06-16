# This doesn't work. Recorded for a future attempt
# https://login.microsoftonline.com/17e16064-c148-4c9b-9892-bb00e9589aa5/adminconsent?client_id=45229de4-72fd-40a8-8960-9efd54679e64&redirect_uri=https://login.microsoftonline.com/common/oauth2/nativeclient
$tenantId = "17e16064-c148-4c9b-9892-bb00e9589aa5"
$clientId = "de2080e0-74ec-4175-9ff7-7a971e1db83d"
$clientSecret = ""

# App: PartnerCentreAutomation
# Client Id: de2080e0-74ec-4175-9ff7-7a971e1db83d
# Local Object Id: 90bbe3f6-ead1-4461-b10b-0c5a628775bd
# Secret:
#
# New key for PartnerCenterAutomation
# Microsoft Entra application info
# Client ID:
# de2080e0-74ec-4175-9ff7-7a971e1db83d
# Key:
#

# App: PartnerCentreAutomation2
# Client Id: 45229de4-72fd-40a8-8960-9efd54679e64
# Local Object Id: 5dd9e443-7fe9-42d5-a7a9-6effe4e0bf6f
# Secret:

try {
   $token = ""
$body = @{
    grant_type    = "client_credentials"
    scope         = "https://api.partnercenter.microsoft.com/.default"
    client_id     = $clientId
    client_secret = $clientSecret
}

$response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Method POST -Body $body
$token = $response.access_token
}
catch {
   Write-Host("Error getting token")
   throw
}
Write-Host("Token retrieved successfully")

try {
   $headers = @{
      Authorization  = "Bearer $token"
      Accept         = "application/json"
   }
   $body = @{
      grant_type    = "jwt_token"
   }

   Write-Host("How is resource to access specified?")
   $response = Invoke-RestMethod -Uri "https://api.partnercenter.microsoft.com/v3/generatetoken" -Method POST -Headers $headers -Body $body
   $response
   $token = $response.access_token
} catch {
   Write-Error $_
   throw "generatetoken failed"
}
 # Get all your commercial marketplace offers
#  $response = Invoke-RestMethod -Uri "https://api.partnercenter.microsoft.com/v1.0/inbound/CommercialMarketplace/offer" -Headers $headers

#  $response.value | Select-Object offerId, name, status

# $response = Invoke-RestMethod -Uri "https://api.partnercenter.microsoft.com/v1/customers" -Headers $headers
