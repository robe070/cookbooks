# Image name using which the VM will be created and the cloud name must be provided as input parameters
Param(
    [Parameter(Mandatory=$true)] [String] $ImgName,
    [Parameter(Mandatory=$true)] [ValidateSet("Azure","AWS")] [String] $CloudName
)

$VMname = "TestImageVM"
if ( -not $script:IncludeDir)
{
    $MyInvocation.MyCommand.Path
    $script:IncludeDir = Join-Path -Path ((Split-Path -Parent $MyInvocation.MyCommand.Path).TrimEnd("Tests")) -ChildPath "scripts"
}
if($CloudName -eq 'Azure') {
    $SkuName = $ImgName
    $ImgName += "image"
    $Location = "Australia East"
    $VmResourceGroup = "BakingDP-$SkuName"
    $ImageResourceGroup = "BakingDP"
    $vmsize="Standard_B4ms"
    $Script:password = "Pcxuser@122robg"
    $AdminUserName = "PCXUSER2"
    try {
        $publicDNSName = "bakingpublicdnsDP-$($VMname)"

        . "$script:IncludeDir\Init-Baking-Includes.ps1"

        Write-Host "$(Log-Date) Delete VM if it already exists"
        . "$script:IncludeDir\Remove-AzrVirtualMachine.ps1"
        Remove-AzrVirtualMachine -Name $VMname -ResourceGroupName $VmResourceGroup -Wait
    
        Write-Host "$(Log-Date) Create VM"
        $SecurePassword = ConvertTo-SecureString $Script:password -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential ($AdminUserName, $SecurePassword);
    
        $NicName = "bakingNic-$($VMname)"
        $nic = Get-AzNetworkInterface -Name $NicName -ResourceGroupName $VmResourceGroup -ErrorAction SilentlyContinue
        if ( $null -eq $nic ) {
            Write-Host "$(Log-Date) Create NIC"
            $externalip = Get-ExternalIP
            $AzVirtualNetworkSubnetConfigName = "bakingSubnet-$($VMname)"
            $AzVirtualNetworkName = "bakingvNET-$($VMname)"
            $AzNetworkSecurityGroupRuleRDPName = "RDPRule-$($VMname)"
            $AzNetworkSecurityGroupRuleWinRMHttpName = "WinRMHttpRule-$($VMname)"
            $AzNetworkSecurityGroupRuleWinRMHttpsName = "WinRMHttpsRule-$($VMname)"
            $AzNetworkSecurityGroupName = "bakingNSG-$($VMname)"
    
            # Create a subnet configuration
            Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
            $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $AzVirtualNetworkSubnetConfigName -AddressPrefix 192.168.1.0/24 -Verbose
    
            # Create a virtual network
            $vnet = New-AzVirtualNetwork -ResourceGroupName $VmResourceGroup -Location $location -Name $AzVirtualNetworkName -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig -Force  -Verbose
    
            # Create a public IP address and specify a DNS name
            $pip = New-AzPublicIpAddress -ResourceGroupName $VmResourceGroup -Location $location -Name $publicDNSName -AllocationMethod Static -IdleTimeoutInMinutes 4 -Force -Verbose
    
            # Create an inbound network security group rule for port 3389
            $nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name $AzNetworkSecurityGroupRuleRDPName  -Protocol Tcp `
            -Direction Inbound -Priority 1000 -SourceAddressPrefix $externalip -SourcePortRange * -DestinationAddressPrefix * `
            -DestinationPortRange 3389 -Access Allow -Verbose
    
            # Create an inbound network security group rule for port 5985
            $nsgRuleWinRMHttp = New-AzNetworkSecurityRuleConfig -Name $AzNetworkSecurityGroupRuleWinRMHttpName  -Protocol Tcp `
            -Direction Inbound -Priority 1010 -SourceAddressPrefix $externalip -SourcePortRange * -DestinationAddressPrefix * `
            -DestinationPortRange 5985 -Access Allow -Verbose
    
            # Create an inbound network security group rule for port 5986
            $nsgRuleWinRMHttps = New-AzNetworkSecurityRuleConfig -Name $AzNetworkSecurityGroupRuleWinRMHttpsName  -Protocol Tcp `
            -Direction Inbound -Priority 1020 -SourceAddressPrefix $externalip -SourcePortRange * -DestinationAddressPrefix * `
            -DestinationPortRange 5986 -Access Allow -Verbose
    
            # Create a network security group
            $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $VmResourceGroup -Location $location `
            -Name $AzNetworkSecurityGroupName -SecurityRules $nsgRuleRDP, $nsgRuleWinRMHttp, $nsgRuleWinRMHttps -Force -Verbose
    
            # Create a virtual network card and associate with public IP address and NSG
            $nic = New-AzNetworkInterface -Name $NicName -ResourceGroupName $VmResourceGroup -Location $location `
            -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id -Verbose
        }
        $image = Get-AzImage -ImageName $ImgName -ResourceGroupName $ImageResourceGroup -Verbose
    
        $diskConfig = New-AzDiskConfig -SkuName "Standard_LRS" -Location $location -CreateOption Empty -DiskSizeGB 32 -Verbose
        $dataDisk1 = New-AzDisk -DiskName "$($VMname)" -Disk $diskConfig -ResourceGroupName $VmResourceGroup -Verbose
        $vm1 = New-AzVMConfig -VMName "$($VMname)" -VMSize $vmsize -Verbose
        $vm1 = Add-AzVMDataDisk -VM $vm1 -Name "$Script:vmname" -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 1 -Verbose
        $vm1 = Set-AzVMOperatingSystem -VM $vm1 -Windows -ComputerName "$($VMname)" -Credential $credential -ProvisionVMAgent -EnableAutoUpdate -Verbose
        $vm1 = Set-AzVMSourceImage -VM $vm1 -Id $image.Id -Verbose
        $vm1 = Add-AzVMNetworkInterface -VM $vm1 -Id $nic.Id -Verbose
        Write-Host "$(Log-Date) VM creation started"
        New-AZVM -ResourceGroupName $VmResourceGroup -VM $vm1 -Verbose -Location $Location -ErrorAction Stop
        Write-Host "$(Log-Date) VM created successfully"
    
        Write-Host "$(Log-Date) Connecting Remote session"
        $ipAddress = Get-AzPublicIpAddress -Name $publicDNSName -Verbose
        $Script:publicDNS =  $ipAddress.IpAddress

        # Used in the Connect-RemoteSession
        $creds = $Credential
        Connect-RemoteSession
    
        Write-Host "$(Log-Date) Executing Test Script in VM"
        Invoke-AzVMRunCommand -ResourceGroupName $VmResourceGroup -Name $VMname -CommandId 'RunPowerShellScript' -ScriptPath "$script:IncludeDir\..\Tests\TestLicenses.ps1" -Parameter @{ImgName = $SkuName} -Verbose | Out-Default | Write-Host
    } catch {
        Write-Host $_.Exception | out-default
        throw "$(Log-Date) Error occured in TestImage file"
    }
    # Remove the VM after the test passed using Pipeline Task
}
