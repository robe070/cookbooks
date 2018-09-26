# Script inspired by https://docs.microsoft.com/en-us/azure/application-gateway/application-gateway-ssl-arm

param (
    [Parameter(Mandatory=$true)]
    [String]$Region = 'East US',

    [Parameter(Mandatory=$true)]
    [String]$ResourceGroup = 'daftruck2',

    [Parameter(Mandatory=$true)]
    [String]$VMSSName = 'daftruck2',

    [Parameter(Mandatory=$true)]
    [String]$CertificateFilePath = 'c:\appgwcert.pfx' ,

    [Parameter(Mandatory=$true)]
    [Security.SecureString]$password
)

'AzureAG.ps1'

Write-Host( "Region : $Region (must be the Display Name e.g. 'East US' not 'eastus' in order for the Application Gateway creation to work")

# Remove warnings that proliferate in the AzureRm cmdlets
$WarningPreference = "SilentlyContinue"
$VerbosePreference = "SilentlyContinue"
$DebugPreference = "SilentlyContinue"

# Make non-terminating errors into terminating errors. That is, the script will throw an exception so we know its gone wrong
$ErrorActionPreference = 'Stop'

try {
    # Pre-existing Resource
    $vnetname = $vmssName + 'vnet'

    # All the rest are not dependent on existing resource names, apart from whats passed in above.
    # So names may be changed if desired
    $agsubnet = $vmssName + '-agsubnet'
    $pipname = $vmssName + '-agpip'

    Write-Host( "Create the Application Gateway Subnet" )
    $vnet = Get-AzureRmVirtualNetwork `
        -ResourceGroupName $ResourceGroup `
        -Name $vnetname

    $subnet = Get-AzureRmVirtualNetworkSubnetConfig `
        -Name $agsubnet `
        -VirtualNetwork $vnet

    if ( $null -eq $subnet ) {
        Add-AzureRmVirtualNetworkSubnetConfig `
            -Name $agsubnet `
            -VirtualNetwork $vnet `
            -AddressPrefix "10.0.1.0/24" | Set-AzureRmVirtualNetwork
    }

    $vnet | Format-List | Write-Host

    Write-Host( "Create the Application Gateway Public IP" )

    $pip = New-AzureRmPublicIpAddress `
        -ResourceGroupName $ResourceGroup `
        -Location $region `
        -Name $pipname `
        -AllocationMethod Dynamic `
        -Force

    Write-Host ( "Create the IP configurations and frontend port" )

    $subnet = Get-AzureRmVirtualNetworkSubnetConfig `
        -Name $agsubnet `
        -VirtualNetwork $vnet

    Write-Host ( "Associate myAGSubnet that was previously created to the application gateway using New-AzureRmApplicationGatewayIPConfiguration.")
    $gipconfigname = $vmssName + '-agIPConfig'
    $gipconfig = New-AzureRmApplicationGatewayIPConfiguration `
        -Name $gipconfigname `
        -Subnet $subnet

    Write-Host ( "Assign myAGPublicIPAddress to the application gateway using New-AzureRmApplicationGatewayFrontendIPConfig.")

    $fipconfigname = $vmssName + '-agFrontEndIPConfig'
    $fipconfig = New-AzureRmApplicationGatewayFrontendIPConfig `
        -Name $fipconfigname `
        -PublicIPAddress $pip

    Write-Host ( "Assign https port to the application gateway using New-AzureRmApplicationGatewayFrontendPort.")

    $frontendportname = $vmssName + '-agFrontEndPort'
    $frontendport = New-AzureRmApplicationGatewayFrontendPort `
        -Name $frontendportname `
        -Port 443

    Write-Host( "Create the backend pool and settings" )
    Write-Host( "Create the backend pool for the application gateway using New-AzureRmApplicationGatewayBackendAddressPool." )

    $AGPoolName = $vmssName + '-agPool'
    $AGPool = New-AzureRmApplicationGatewayBackendAddressPool `
    -Name $AGPoolName

    Write-Host( "Configure the settings for the backend pool using New-AzureRmApplicationGatewayBackendHttpSettings." )

    $AGPoolSettingsName = $vmssName + '-agPoolSettings'
    $AGPoolSettings = New-AzureRmApplicationGatewayBackendHttpSettings `
        -Name $AGPoolSettingsName `
        -Port 80 `
        -Protocol Http `
        -CookieBasedAffinity Enabled `
        -RequestTimeout 120

    Write-Host( "A listener is required to enable the application gateway to route traffic appropriately to the backend pool.")
    # In this example, you create a basic listener that listens for HTTPS traffic at the root URL.
    #   Create a certificate object using New-AzureRmApplicationGatewaySslCertificate and then create a listener named mydefaultListener using
    #  New-AzureRmApplicationGatewayHttpListener with the frontend configuration, frontend port, and certificate that you previously created.
    # A rule is required for the listener to know which backend pool to use for incoming traffic. Create a basic rule named rule1 using New-AzureRmApplicationGatewayRequestRoutingRule.

    Write-Host( "Upload the certificate")
    $cert = New-AzureRmApplicationGatewaySslCertificate `
        -Name $($vmssName + "appgwcert") `
        -CertificateFile $CertificateFilePath `
        -Password $password

    Write-Host( "Create the default listener")

    $defaultlistenerName = $vmssName + '-agListener'
    $defaultlistener = New-AzureRmApplicationGatewayHttpListener `
        -Name $defaultlistenerName `
        -Protocol Https `
        -FrontendIPConfiguration $fipconfig `
        -FrontendPort $frontendport `
        -SslCertificate $cert

    Write-Host( "Create the default listener rule with Backend Pool seetings")

    $frontendRuleName = $vmssName + '-agRule'
    $frontendRule = New-AzureRmApplicationGatewayRequestRoutingRule `
        -Name $frontendRuleName `
        -RuleType Basic `
        -HttpListener $defaultlistener `
        -BackendAddressPool $AGPool `
        -BackendHttpSettings $AGPoolSettings

    Write-Host( "Create the application gateway with the certificate")
    # Now that you created the necessary supporting resources, specify parameters for the application gateway named
    # myAppGateway using New-AzureRmApplicationGatewaySku, and then create it using New-AzureRmApplicationGateway with the certificate.

    $sku = New-AzureRmApplicationGatewaySku `
        -Name Standard_Medium `
        -Tier Standard `
        -Capacity 2

    $appgwName.GetType()
    $ResourceGroup.GetType()
    $Region.GetType()
    $AGPool.GetType()
    $AGPoolSettings.GetType()
    $fipconfig.GetType()
    $gipconfig.GetType()
    $frontendport.GetType()
    $defaultlistener.GetType()
    $frontendRule.GetType()
    $sku.GetType()
    $cert.GetType()

    $appgwName = $vmssName + '-ag'
    $appgw = New-AzureRmApplicationGateway `
        -Name $appgwName `
        -ResourceGroupName $ResourceGroup `
        -Location $Region`
        -BackendAddressPools $AGPool `
        -BackendHttpSettingsCollection $AGPoolSettings `
        -FrontendIpConfigurations $fipconfig `
        -GatewayIpConfigurations $gipconfig `
        -FrontendPorts $frontendport `
        -HttpListeners $defaultlistener `
        -RequestRoutingRules $frontendRule `
        -Sku $sku `
        -SslCertificates $cert
    # $appgw | Format-List | Write-Host

    if ( $false ) {
        Write-Host( "Add Application Gateway to VMSS")

        $ipConfig = New-AzureRmVmssIpConfig `
            -Name $($VMSSName + 'VmssIpConfig') `
            -SubnetId $subnet.Id `
            -ApplicationGatewayBackendAddressPoolsId $AGPool.Id

        $VMSS = Get-AzureRmVmss -ResourceGroupName $ResourceGroup -VMScaleSetName $VMSSName
        Add-AzureRmVmssNetworkInterfaceConfiguration -VirtualMachineScaleSet $VMSS -Name $VMSSName -Primary $True -IPConfiguration $ipConfig
        Update-AzureRmVmss -ResourceGroupName $ResourceGroup -VirtualMachineScaleSet $VMSS -VMScaleSetName $VMSSName
    }
} catch {
    $_
    Write-Host ("Fatal Error")
    Write-Host( "This message may mean the Location field is not valid! 'Generic types are not supported for input fields at this time'")
    Exit
}
Write-Host( "Successful" )