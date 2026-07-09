function Remove-AzrVirtualMachine {
    <#
    .SYNOPSIS
        This function is used to remove any Azure VMs as well as any attached disks (managed or unmanaged). By default, this function creates a job
        due to the time it takes to remove an Azure VM.

    .EXAMPLE
        PS> Get-AzVm -Name 'BAPP07GEN22' | Remove-AzrVirtualMachine

        This example removes the Azure VM BAPP07GEN22 as well as any disks attached to it.

    .PARAMETER VMName
        The name of an Azure VM. This has an alias of Name which can be used as pipeline input from the Get-AzVM cmdlet.

    .PARAMETER ResourceGroupName
        The name of the resource group the Azure VM is a part of.

    .PARAMETER Credential
        Optional credentials for logging into Azure if not already logged in.

    .PARAMETER Wait
        If you'd rather wait for the Azure VM to be removed before returning control to the console, use this switch parameter.
        If not, it will create a job and return a PSJob back.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param
    (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string]$VMName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [Parameter()]
        [pscredential]$Credential,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [switch]$Wait
    )
    process {
        $scriptBlock = {
            param (
                $VMName,
                $ResourceGroupName
            )
            $commonParams = @{
                'Name'              = $VMName
                'ResourceGroupName' = $ResourceGroupName
            }
            $vm = Get-AzVM @commonParams -ErrorAction SilentlyContinue

            if ($null -eq $vm) {
                Write-Host "VM $VMName not found in resource group $ResourceGroupName"
                return $null
            }

            #region Remove the boot diagnostics disk
            if ($vm.DiagnosticsProfile -and $vm.DiagnosticsProfile.BootDiagnostics -and $vm.DiagnosticsProfile.BootDiagnostics.Enabled) {
                Write-Host -Message 'Removing boot diagnostics storage container...'
                $diagSa = [regex]::match($vm.DiagnosticsProfile.BootDiagnostics.StorageUri, '^http[s]?://(.+?)\.').groups[1].value

                if ($diagSa) {
                    $VMNameMangled = $vm.Name
                    $VMNameMangled = $VMNameMangled -Replace '[-]' # Strip -
                    if ($VMNameMangled.Length -gt 9) {
                        $i = 9
                    } else {
                        $i = $VMNameMangled.Length
                    }
                    $VMNameMangled = $VMNameMangled.ToLower().Substring(0, $i) # Lower case, and truncate to 8 chars if necessary

                    #region Get the VM ID
                    $azResourceParams = @{
                        'ResourceName'      = $VMName
                        'ResourceType'      = 'Microsoft.Compute/virtualMachines'
                        'ResourceGroupName' = $ResourceGroupName
                    }
                    $vmResource = Get-AzResource @azResourceParams
                    $vmId = $vmResource.Properties.VmId
                    #endregion

                    $diagContainerName = ('bootdiagnostics-{0}-{1}' -f $VMNameMangled, $vmId)
                    $diagSaRg = (Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $diagSa }).ResourceGroupName
                    $saParams = @{
                        'ResourceGroupName' = $diagSaRg
                        'Name'              = $diagSa
                    }

                    $storageAccount = Get-AzStorageAccount @saParams -ErrorAction SilentlyContinue
                    if ($storageAccount) {
                        $container = $storageAccount | Get-AzStorageContainer | Where-Object { $_.Name -eq $diagContainerName }
                        if ($container) {
                            Remove-AzStorageContainer -Name $diagContainerName -Context $storageAccount.Context -Force -ErrorAction Stop
                        } else {
                            Write-Host "Boot diagnostics container $diagContainerName not found."
                        }
                    } else {
                        Write-Host "Storage account $diagSa for boot diagnostics not found."
                    }
                } else {
                    Write-Host "No valid storage URI found for boot diagnostics."
                }
            } else {
                Write-Host "Boot diagnostics not enabled for VM $VMName or DiagnosticsProfile not available."
            }
            #endregion

            Write-Host -Message 'Removing the Azure VM...'
            $null = $vm | Remove-AzVM -Force

            Write-Host -Message 'Removing the Azure network interface...'
            $nsgIds = @()
            foreach ($nicUri in $vm.NetworkProfile.NetworkInterfaces.Id) {
                $nic = Get-AzNetworkInterface -ResourceGroupName $vm.ResourceGroupName -Name $nicUri.Split('/')[-1]
                # Capture any NSG attached to this NIC so it can be removed once the NIC is gone
                if ($nic.NetworkSecurityGroup -and $nic.NetworkSecurityGroup.Id) {
                    $nsgIds += $nic.NetworkSecurityGroup.Id
                }
                Remove-AzNetworkInterface -Name $nic.Name -ResourceGroupName $vm.ResourceGroupName -Force
                foreach ($ipConfig in $nic.IpConfigurations) {
                    if ($ipConfig.PublicIpAddress -ne $null) {
                        Write-Host -Message 'Removing the Public IP Address...'
                        Remove-AzPublicIpAddress -ResourceGroupName $vm.ResourceGroupName -Name $ipConfig.PublicIpAddress.Id.Split('/')[-1] -Force
                    }
                }
            }

            # Remove the network security group(s) that were attached to the NIC(s).
            # Must happen after the NIC is removed - an NSG cannot be deleted while still in use.
            foreach ($nsgId in ($nsgIds | Select-Object -Unique)) {
                $nsgName = $nsgId.Split('/')[-1]
                $nsgRg = $nsgId.Split('/')[4]
                Write-Host -Message "Removing the network security group $nsgName..."
                Remove-AzNetworkSecurityGroup -ResourceGroupName $nsgRg -Name $nsgName -Force -ErrorAction Stop
            }

            # Remove the OS disk
            Write-Host -Message 'Removing OS disk...'
            if ($vm.StorageProfile.OsDisk.ManagedDisk) {
                # Managed disk
                $osDiskName = $vm.StorageProfile.OsDisk.Name
                Write-Host "Removing managed OS disk $osDiskName..."
                $disk = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $osDiskName -ErrorAction SilentlyContinue
                if ($disk) {
                    Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $osDiskName -Force -ErrorAction Stop
                } else {
                    Write-Host "Managed OS disk $osDiskName not found."
                }
            } elseif ($vm.StorageProfile.OsDisk.Vhd -and (Get-Member -InputObject $vm.StorageProfile.OsDisk.Vhd -Name "Uri" -MemberType Properties)) {
                # Unmanaged disk
                $osDiskId = $vm.StorageProfile.OsDisk.Vhd.Uri
                $osDiskContainerName = $osDiskId.Split('/')[-2]
                $osDiskStorageAcct = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $osDiskId.Split('/')[2].Split('.')[0] }
                if ($osDiskStorageAcct) {
                    Write-Host "Removing unmanaged OS disk blob $osDiskId..."
                    $osDiskStorageAcct | Remove-AzStorageBlob -Container $osDiskContainerName -Blob $osDiskId.Split('/')[-1] -ErrorAction Stop
                    # Remove the status blob
                    Write-Host -Message 'Removing the OS disk status blob...'
                    $osDiskStorageAcct | Get-AzStorageBlob -Container $osDiskContainerName -Blob "$($vm.Name)*.status" | Remove-AzStorageBlob -ErrorAction Stop
                } else {
                    Write-Host "Storage account for unmanaged OS disk $osDiskId not found."
                }
            } else {
                Write-Host "No OS disk found for VM $VMName."
            }

            # Remove any attached data disks
            if ($vm.StorageProfile.DataDisks) {
                Write-Host -Message 'Removing data disks...'
                foreach ($dataDisk in $vm.StorageProfile.DataDisks) {
                    if ($dataDisk.ManagedDisk) {
                        # Managed data disk
                        $dataDiskName = $dataDisk.Name
                        Write-Host "Removing managed data disk $dataDiskName..."
                        $disk = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $dataDiskName -ErrorAction SilentlyContinue
                        if ($disk) {
                            Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $dataDiskName -Force -ErrorAction Stop
                        } else {
                            Write-Host "Managed data disk $dataDiskName not found."
                        }
                    } elseif ($dataDisk.Vhd -and (Get-Member -InputObject $dataDisk.Vhd -Name "Uri" -MemberType Properties)) {
                        # Unmanaged data disk
                        $dataDiskUri = $dataDisk.Vhd.Uri
                        $dataDiskStorageAcct = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $dataDiskUri.Split('/')[2].Split('.')[0] }
                        if ($dataDiskStorageAcct) {
                            Write-Host "Removing unmanaged data disk blob $dataDiskUri..."
                            $dataDiskStorageAcct | Remove-AzStorageBlob -Container $dataDiskUri.Split('/')[-2] -Blob $dataDiskUri.Split('/')[-1] -ErrorAction Stop
                        } else {
                            Write-Host "Storage account for unmanaged data disk $dataDiskUri not found."
                        }
                    }
                }
            }
        }

        if ($Wait.IsPresent) {
            & $scriptBlock -VMName $VMName -ResourceGroupName $ResourceGroupName
        } else {
            $initScript = {
                Import-Module Az.Accounts
                $null = Connect-AzAccount -Credential $args[0]
            }
            $jobParams = @{
                'ScriptBlock'          = $scriptBlock
                'InitializationScript' = $initScript
                'ArgumentList'         = @($VMName, $ResourceGroupName)
                'Name'                 = "Azure VM $VMName Removal"
            }
            Start-Job @jobParams
        }
    }
}