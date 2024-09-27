Param(
    [Parameter(mandatory)]
    [ValidateSet('AzureProjectSP','PowershellScriptsSP','LPC','LPC-DP','LPC-AsDP','LPC-AsBake','LANSAInc', 'KeyVault')]
    [string] $CloudAccount,

    # Parameter help description
    [Parameter(Mandatory=$false)]
    [securestring]
    $CloudSecret
)
$ServicePrincipal = $false

switch ( $CloudAccount ) {
   {$_ -eq 'AzureProjectSP'} {
      # Display Name: VisualLansa-Lansa Azure Scalable License Images-739c4e86-bd75-4910-8d6e-d7eb23ab94f3
      $TenantName = 'DefaultDirectory'
      $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
      $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
      $User = '84a6e066-e983-4520-a1ba-8662424bc4da'
      $ServicePrincipal = $True
   }
   {$_ -eq 'PowershellScriptsSP'} {
      $TenantName = 'DefaultDirectory'
      $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
      $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
      $User = '165a4c36-501f-4c3b-8828-8e812ef1041f'
      $ServicePrincipal = $True
   }
   {$_ -eq 'LPC'} {
      $TenantName = 'DefaultDirectory'
      $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
      $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
      $User = 'Any user - it will be prompted'
   }
   {$_ -eq 'LANSAInc'} {
      $TenantName = 'LANSA Inc'
      $Tenant = '3a9638cf-42dc-4c21-95b5-c691e47eef65'
      $Subscription = 'b837dfa9-fc6c-4a44-ae38-94964ea035a3'
      $User = 'Any user - it will be prompted'
   }
   {$_ -eq 'KeyVault'} {
      # Is this still being used? robert.goodridge@idera.com, robert.goodridge@lansa.com.au and
      # robert@lansacloudlansacom.onmicrosoft.com, do not have access to this subscription
      $TenantName = 'LANSA Inc'
      $Tenant = '3a9638cf-42dc-4c21-95b5-c691e47eef65'
      $Subscription = 'ffe7f8f1-c8cb-425c-ad93-bbd52cffe4ed'
      $User = 'Any user - it will be prompted'
   }
}

Write-Host( "Connecting $CloudAccount using User $user to Tenant $TenantName & subscription $subscription")

Clear-AzContext -Force

if ( $CloudSecret ) {
    $Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $user, $CloudSecret
} else {
    #$Credential = Get-Credential -UserName $user -Message "Enter password for $user"
}

if ($ServicePrincipal) {
   Connect-AzAccount -ServicePrincipal -Credential $Credential -Tenant $Tenant -Subscription $Subscription
} else {
   Connect-AzAccount -Tenant $Tenant -Subscription $Subscription
}

Set-AzContext -Tenant $Tenant -SubscriptionId $Subscription
