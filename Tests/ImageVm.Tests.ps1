<#
This script is used to test the image from the Image Build Pipeline using a VM:
Sample Command:
Invoke-Pester -Path '.\ImageVm.Tests.ps1' -OutputFormat  NUnitXml -OutputFile VmTests.xml
#>

# Define Pester Tests
Describe "VM Tests" {
    # Setup the Pester environment
    BeforeAll {
        # Image name using which the VM will be created and the cloud name must be provided as environment variables
        # Environment variables are set before running the tests
        $ImgName = $env:TestImageName
        $ImgName | Out-Default | Write-Host

        $CloudName = $env:TestCloudName
        $CloudName | Out-Default | Write-Host

        $VMname = "TestImageVM"
        if ($env:TestVmName) {
            $VMname = $env:TestVmName
        }
        $AtomicBuild = $false
        if ($env:AtomicBuild -eq "True") {
            $AtomicBuild = $true
        }

        $VMname | Out-Default | Write-Host

        # set up environment if not yet setup
        if ( -not $script:IncludeDir)
        {
            # Log-Date can't be used yet as Framework has not been loaded

            Write-Host "Initialising environment - presumed not running through RemotePS"
            Write-Host $PSCommandPath
            $script:IncludeDir = Join-Path -Path ((Split-Path -Parent $PSCommandPath).TrimEnd("Tests")) -ChildPath "scripts"

            . "$script:IncludeDir\Init-Baking-Vars.ps1"
            . "$script:IncludeDir\Init-Baking-Includes.ps1"
            . "$script:IncludeDir\dot-CommonTools.ps1"
        }
        else
        {
            Write-Host "$(Log-Date) Environment already initialised"
        }

        if($CloudName -eq 'Azure') {
            $SkuName = $ImgName
            $ImgName += "image"
            $Location = "Australia East"
            $VmResourceGroup = "BakingDP-$SkuName"
            $ImageResourceGroup = "BakingDP"
            if ($AtomicBuild) {
                $ImageResourceGroup = $VmResourceGroup
            }
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
                    $externalip | Out-Default | Write-Host
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
            
                $vm1 = New-AzVMConfig -VMName "$($VMname)" -VMSize $vmsize -Verbose
                $Script:vmname = $VMname
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
                #Connect-RemoteSession
            } catch {
                Write-Host $_.Exception | out-default
                throw "$(Log-Date) Error occured in TestImage file"
            }
            # Remove the VM after the test passed using Pipeline Task
        }
        elseif ($CloudName -eq 'AWS') {
            $imageId = $ImgName
            $script:keypairfile = $env:keypairpath
            $script:instancename = " $VMName LANSA Scalable License installed on $(Log-Date)"
            . "$script:IncludeDir\dot-Create-EC2Instance.ps1"
            Create-EC2Instance $imageId $env:keypair $env:SG -InstanceType 't2.large'
            Write-Host "Password is $script:password"
            $securepassword = ConvertTo-SecureString $Script:password -AsPlainText -Force
            $AdminUserName = "Administrator"
            $creds = New-Object System.Management.Automation.PSCredential ($AdminUserName, $securepassword)
            Connect-RemoteSession

        }
    }

    Context "License" {
        It 'Activates the licenses properly' {
            $errorThrown = $false
            try{
                Write-Host "$(Log-Date) Executing Licenses Test Script in VM"
                if($CloudName -eq 'Azure') {
                    Invoke-AzVMRunCommand -ResourceGroupName $VmResourceGroup -Name $VMname -CommandId 'RunPowerShellScript' -ScriptPath "$script:IncludeDir\..\Tests\TestLicenses.ps1" -Parameter @{ImgName = $SkuName} -Verbose | Out-Default | Write-Host
                }
                elseif($CloudName -eq 'AWS'){
                    . "$script:InclueDir\dot-Execute-RemoteScript.ps1"
                    Execute-RemoteScript -Session $script:session -FilePath $script:IncludeDir\..\Tests\TestLicenses.ps1 -ArgumentList @($imageId)
                }
            } catch {
                $errorThrown = $true
                Write-Host $_.Exception | out-default
            }
            $errorThrown | Should -Be $false
        }
    }

    Context "Version" {
        It 'Matches the Version text' {
            $errorThrown = $false
            try{
                Write-Host "$(Log-Date) Executing Image Version Test Script in VM"
                Invoke-AzVMRunCommand -ResourceGroupName $VmResourceGroup -Name $VMname -CommandId 'RunPowerShellScript' -ScriptPath "$script:IncludeDir\..\Tests\TestImageVersion.ps1" -Parameter @{ImgName = $SkuName} -Verbose | Out-Default | Write-Host
            } catch {
                Write-Host $_.Exception | out-default
                $errorThrown = $true
            }
            $errorThrown | Should -Be $false
        }
    }
}