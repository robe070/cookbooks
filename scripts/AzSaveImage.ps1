$Location = "Australia East"
$VersionText = 'w19d150rjg-j'
$ImageName = "$($VersionText)image"
$VmResourceGroup = "BakingDP-$($VersionText)"
$ImageResourceGroup = 'BakingDP'
$vmname = "$($VersionText)"

#Get-AzImage -ResourceGroupName $ImageResourceGroup -ImageName $ImageName -ErrorAction SilentlyContinue | Remove-AzImage -Force -ErrorAction SilentlyContinue | Out-Default | Write-Host

Write-Host "$(Log-Date) Terminating VM..."
#Stop-AzVM -ResourceGroupName $VmResourceGroup -Name $Script:vmname -Force | Out-Default | Write-Host

Write-Host "$(Log-Date) Creating Actual Image..."
Set-AzVM -ResourceGroupName $VmResourceGroup -Name $Script:vmname -Generalized | Out-Default | Write-Host
$vm = Get-AzVM -ResourceGroupName $VmResourceGroup -Name $Script:vmname
$image = New-AzImageConfig -Location $location -SourceVirtualMachineId $vm.Id

New-AzImage -ResourceGroupName $ImageResourceGroup -Image $image -ImageName $ImageName | Out-Default | Write-Host