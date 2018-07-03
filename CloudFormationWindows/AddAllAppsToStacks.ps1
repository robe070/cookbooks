# Add all apps to evaluation stacks - to add them all back in with different settings
# Possibly with a change of application.msi
"AddAllAppsToStacks.ps1"

$ApplCount = 10
$StackStart = 30
$StackEnd = 30
$Region = 'us-east-1'
For ( $i = $StackStart; $i -le $StackEnd; $i++) {
    Write-Host("stack-name eval$($i)")

    # Reset the GracePeriod so the stack has time to deploy the new apps before the ASG times them out

    $ASGInstances = @(Get-ASAutoScalingInstance -Region $Region | where-object {$_.AutoScalingGroupName -like "eval$($i)-" } )
    # $ASGInstances | Format-Table
    foreach ( $ASGInstance in $ASGInstances ) {
            Write-FormattedOutput "$($ASGInstance.AutoScalingGroupName) $($ASGInstance.InstanceId). Resetting Grace Period..." -ForegroundColor 'Yellow'  | Out-Host
            Set-ASInstanceHealth -Region "$Region" -HealthStatus Healthy -InstanceId $ASGInstance.InstanceId -ShouldRespectGracePeriod $true   | Out-Host
    }
    
    aws cloudformation update-stack --stack-name eval$($i) --region $Region --capabilities CAPABILITY_IAM --template-url https://lansa.s3.ap-southeast-2.amazonaws.com/templates/support/L4W14200_paas/lansa-win-paas.cfn.template --parameters ParameterKey=03ApplCount,ParameterValue=$ApplCount,UsePreviousValue=false ParameterKey=03DBUsername,UsePreviousValue=true ParameterKey=04DBPassword,UsePreviousValue=true ParameterKey=05WebUser,UsePreviousValue=true ParameterKey=06WebPassword,UsePreviousValue=true ParameterKey=07KeyName,UsePreviousValue=true ParameterKey=08RemoteAccessLocation,UsePreviousValue=true ParameterKey=10LansaGitRepoBranch,UsePreviousValue=true ParameterKey=11WebServerInstanceTyp,UsePreviousValue=true ParameterKey=12WebServerMaxConnec,UsePreviousValue=true ParameterKey=13DBInstanceClass,UsePreviousValue=true ParameterKey=14DBName,UsePreviousValue=true ParameterKey=15DBEngine,UsePreviousValue=true ParameterKey=18WebServerCapacity,UsePreviousValue=true ParameterKey=19DBAllocatedStorage,UsePreviousValue=true ParameterKey=20DBIops,UsePreviousValue=true ParameterKey=DomainName,UsePreviousValue=true ParameterKey=DomainPrefix,UsePreviousValue=true ParameterKey=StackNumber,UsePreviousValue=true ParameterKey=WebServerGitRepo,UsePreviousValue=true ParameterKey=22AppToReinstall,UsePreviousValue=true ParameterKey=22TriggerAppReinstall,UsePreviousValue=true ParameterKey=22TriggerAppUpdate,ParameterValue=$ApplCount,UsePreviousValue=false ParameterKey=22TriggerCakeUpdate,UsePreviousValue=true ParameterKey=23TriggerChefUpdate,UsePreviousValue=true ParameterKey=24TriggerWinUpdate,UsePreviousValue=true ParameterKey=25TriggerWebConfig,UsePreviousValue=true ParameterKey=26TriggerIcingUpdate,UsePreviousValue=true ParameterKey=01LansaMSI,UsePreviousValue=true ParameterKey=02LansaMSIBitness,UsePreviousValue=true ParameterKey=03ApplMSIuri,UsePreviousValue=true ParameterKey=17UserScriptHook,UsePreviousValue=true ParameterKey=19HostRoutePortNumber,UsePreviousValue=true ParameterKey=19HTTPPortNumber,UsePreviousValue=true ParameterKey=19HTTPPortNumberHub,UsePreviousValue=true ParameterKey=19JSMAdminPortNumber,UsePreviousValue=true ParameterKey=19JSMPortNumber,UsePreviousValue=true ParameterKey=21ELBTimeout,UsePreviousValue=true ParameterKey=27TriggerPatchInstall,UsePreviousValue=true ParameterKey=28PatchBucketName,UsePreviousValue=true ParameterKey=29PatchFolderName,UsePreviousValue=true ParameterKey=SSLCertificateARN,UsePreviousValue=true   | Out-Host
    Write-Host( "*********************************************")
}
