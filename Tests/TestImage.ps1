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
    $Location = "Australia East"
    $svcName = "BakingDP"
    $vmsize="Standard_B4ms"
    $Script:password = "Pcxuser@122"
    $AdminUserName = "PCXUSER2"
    try {
        $publicDNSName = "bakingpublicdnsDP-$($VMname)"

        . "$script:IncludeDir\Init-Baking-Includes.ps1"

        Write-Host "$(Log-Date) Delete VM if it already exists"
        . "$script:IncludeDir\Remove-AzrVirtualMachine.ps1"
        Remove-AzrVirtualMachine -Name $VMname -ResourceGroupName $svcName -Wait
    
        Write-Host "$(Log-Date) Create VM"
        $SecurePassword = ConvertTo-SecureString $Script:password -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential ($AdminUserName, $SecurePassword);
    
        $NicName = "bakingNic-$($VMname)"
        $nic = Get-AzNetworkInterface -Name $NicName -ResourceGroupName $svcName -ErrorAction SilentlyContinue
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
            $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $AzVirtualNetworkSubnetConfigName -AddressPrefix 192.168.1.0/24
    
            # Create a virtual network
            $vnet = New-AzVirtualNetwork -ResourceGroupName $svcName -Location $location -Name $AzVirtualNetworkName -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig -Force
    
            # Create a public IP address and specify a DNS name
            $pip = New-AzPublicIpAddress -ResourceGroupName $svcName -Location $location -Name $publicDNSName -AllocationMethod Static -IdleTimeoutInMinutes 4 -Force
    
            # Create an inbound network security group rule for port 3389
            $nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name $AzNetworkSecurityGroupRuleRDPName  -Protocol Tcp `
            -Direction Inbound -Priority 1000 -SourceAddressPrefix $externalip -SourcePortRange * -DestinationAddressPrefix * `
            -DestinationPortRange 3389 -Access Allow
    
            # Create an inbound network security group rule for port 5985
            $nsgRuleWinRMHttp = New-AzNetworkSecurityRuleConfig -Name $AzNetworkSecurityGroupRuleWinRMHttpName  -Protocol Tcp `
            -Direction Inbound -Priority 1010 -SourceAddressPrefix $externalip -SourcePortRange * -DestinationAddressPrefix * `
            -DestinationPortRange 5985 -Access Allow
    
            # Create an inbound network security group rule for port 5986
            $nsgRuleWinRMHttps = New-AzNetworkSecurityRuleConfig -Name $AzNetworkSecurityGroupRuleWinRMHttpsName  -Protocol Tcp `
            -Direction Inbound -Priority 1020 -SourceAddressPrefix $externalip -SourcePortRange * -DestinationAddressPrefix * `
            -DestinationPortRange 5986 -Access Allow
    
            # Create a network security group
            $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $svcName -Location $location `
            -Name $AzNetworkSecurityGroupName -SecurityRules $nsgRuleRDP, $nsgRuleWinRMHttp, $nsgRuleWinRMHttps -Force
    
            # Create a virtual network card and associate with public IP address and NSG
            $nic = New-AzNetworkInterface -Name $NicName -ResourceGroupName $svcName -Location $location `
            -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id
        }
        $image = Get-AzImage -ImageName $ImgName -ResourceGroupName "BAKINGDP"
    
        $diskConfig = New-AzDiskConfig -SkuName "Standard_LRS" -Location $location -CreateOption Empty -DiskSizeGB 32
        $dataDisk1 = New-AzDisk -DiskName "$($VMname)" -Disk $diskConfig -ResourceGroupName $svcName
        $vm1 = New-AzVMConfig -VMName "$($VMname)" -VMSize $vmsize
        $vm1 = Add-AzVMDataDisk -VM $vm1 -Name "$Script:vmname" -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 1
        $vm1 = Set-AzVMOperatingSystem -VM $vm1 -Windows -ComputerName "$($VMname)" -Credential $credential -ProvisionVMAgent -EnableAutoUpdate
        $vm1 = Set-AzVMSourceImage -VM $vm1 -Id $image.Id
        $vm1 = Add-AzVMNetworkInterface -VM $vm1 -Id $nic.Id
        New-AZVM -ResourceGroupName $svcName -VM $vm1 -Verbose -Location $Location -ErrorAction Stop
        Write-Host "$(Log-Date) VM created successfully"
    
        Write-Host "$(Log-Date) Connecting Remote session"
        $ipAddress = Get-AzPublicIpAddress -Name $publicDNSName
        $Script:publicDNS =  $ipAddress.IpAddress
        $creds = $Credential
        Connect-RemoteSession
    
        Write-Host "$(Log-Date) Executing Test Script in VM"
        Invoke-AzVMRunCommand -ResourceGroupName $svcName -Name $VMname -CommandId 'RunPowerShellScript' -ScriptPath "$script:IncludeDir\..\Tests\TestLicenses.ps1" | Out-Default | Write-Host
    } catch {
        throw "$(Log-Date) Error occured in TestImage file"
    } Finally {
        Write-Host "$(Log-Date) Removing VM post test execution"
        . "$script:IncludeDir\Remove-AzrVirtualMachine.ps1"
        Remove-AzrVirtualMachine -Name $VMname -ResourceGroupName $svcName -Wait
    }
}
