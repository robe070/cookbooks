Param(
    [Parameter(mandatory)]
        [ValidateSet('LPC','LANSAInc', 'KeyVault')]
        [string] $CloudAccount
)

switch ( $CloudAccount ) {
    {$_ -eq 'LPC'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = 'edff5157-5735-4ceb-af94-526e2c235e80'
        $User = 'robert@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'LANSAInc'} {
        $TenantName = 'LANSA Inc'
        $Tenant = '3a9638cf-42dc-4c21-95b5-c691e47eef65'
        $Subscription = 'b837dfa9-fc6c-4a44-ae38-94964ea035a3'
        $User = 'rob.goodridge@lansa.com.au'
    }
    {$_ -eq 'KeyVault'} {
        $TenantName = 'LANSA Inc'
        $Tenant = '3a9638cf-42dc-4c21-95b5-c691e47eef65'
        $Subscription = 'ffe7f8f1-c8cb-425c-ad93-bbd52cffe4ed'
        $User = 'rob.goodridge@lansa.com.au'
    }
}

Write-Host( "Connecting $CloudAccount using User $user to Tenant $TenantName & subscription $subscription")

#Connect-AzAccount -SubscriptionId edff5157-5735-4ceb-af94-526e2c235e80
#Connect-AzAccount -SubscriptionId ffe7f8f1-c8cb-425c-ad93-bbd52cffe4ed
Clear-AzContext -Force

$Credential = Get-Credential
Connect-AzAccount -Credential $Credential -Tenant $Tenant -Subscription $Subscription
Set-AzContext -Tenant $Tenant -SubscriptionId $Subscription