Param(
    [Parameter(mandatory)]
        [ValidateSet('NS','VR','PKU','VC','HT','RM','AK','SS','AS','PK', 'LPC','LPC-DP','LPC-AsDP','LPC-AsBake','LANSAInc', 'KeyVault')]
        [string] $CloudAccount
)

switch ( $CloudAccount ) {
    {$_ -eq 'LPC-MSDN'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = 'edff5157-5735-4ceb-af94-526e2c235e80'
        $User = 'robert@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'LPC-DP'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
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
    {$_ -eq 'LPC-AsDP'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = 'robAsDP@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'LPC-AsBake'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = 'robAsBake@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'HT'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = 'HarishThota@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'RM'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = 'RichaMangalick@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'AK'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = 'AshutoshKumar@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'SS'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = 'ShashikantSharma@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'AS'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = 'AparnaSathyanarayana@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'PK'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = 'PravirKarna@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'VC'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = 'VarunChopra@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'PKU'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = 'PratapKurapati@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'VR'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = 'VenkateshRamagiri@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'NS'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = 'NagasekharSuryadevara@lansacloudlansacom.onmicrosoft.com'
    }
}

Write-Host( "Connecting $CloudAccount using User $user to Tenant $TenantName & subscription $subscription")

#Connect-AzAccount -SubscriptionId edff5157-5735-4ceb-af94-526e2c235e80
#Connect-AzAccount -SubscriptionId ffe7f8f1-c8cb-425c-ad93-bbd52cffe4ed
Clear-AzContext -Force

if ( $clientsecret ) {
    $secret = ConvertTo-SecureString -String $clientsecret -AsPlainText -Force
    $Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $user, $secret
} else {
    $Credential = Get-Credential -UserName $user -Message "Enter password for $user"
}

Connect-AzAccount -Credential $Credential -Tenant $Tenant -Subscription $Subscription
Set-AzContext -Tenant $Tenant -SubscriptionId $Subscription
