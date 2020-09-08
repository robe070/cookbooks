try
{
    $envId = $args[0]
    $oldPassword = $args[1]

    Push-Location

    Write-Host("*** GitHub access is using Personal Access Tokens (PAT) ***")

    $sshKeyFileLocation = "C:\LANSA Internal System\PaaS\Keys"
    $keyName = "lansaeval122"
    $keyId = ""
    $userid = "lansaeval" + $envId
    $sshKeyDirectory = "$sshKeyFileLocation\lansaeval$envId"
    $sshKeyFile = "$sshKeyDirectory\lansaeval122_rsa.pub"
    Write-Output $userid $pwd $sshKeyFile
    $chgDate = Get-Date -UFormat "%Y%m%d"
    $backupDir = "${sshKeyDirectory}_$chgDate"
    if ( -not (Test-Path $backupDir ) )
    {
        Rename-Item -path $sshKeyDirectory -newName $backupDir -ErrorAction SilentlyContinue
    }

    if ( -not (Test-Path $sshKeyDirectory ) )
    {
        New-Item -ItemType Directory -Force -Path $sshKeyDirectory
    }
    else
    {
        Remove-Item -path $sshKeyDirectory\lansaeval122_rsa*
    }
    # Set the current directory so the key gets generated straight into the correct directory
    Set-Location -Path $sshKeyDirectory
    # Need "--%" otherwise it will get a "Too many arguments" error.
    # https://github.com/PowerShell/Win32-OpenSSH/issues/1017
    #ssh-keygen.exe --% -t rsa -b 4096 -C "lansaeval207@lansa.com" -N "" -f "lansaeval122_rsa"
    ssh-keygen.exe --% -t rsa -b 4096 -C lansaeval$envId@lansa.com -N "" -f lansaeval122_rsa
    Write-Output "Key Gen completed"

    $PasswordPath = '\\lansasrvnewer\lansa\FreeTrialGitHubPasswords.csv'
    Write-Host("Get the password from $PasswordPath")
    $PasswordFile = Import-Csv ($PasswordPath)

    $PasswordMap = @{}
    $PasswordFile | foreach { $PasswordMap[$_.repo] = $_.pat }

    $password = $passwordMap[$userid]

    $credentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($userid + ":" + $password))
    $headers = @{ 'Authorization' = "Basic $credentials" }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Write-Output "Get keys list"
    # curl -u "userid:password" https://api.github.com/user
    $response = Invoke-WebRequest -uri "https://api.github.com/user/keys" -Headers $headers -UseBasicParsing
    $responseX = $response.content | Out-String | ConvertFrom-Json
    $responseX | Out-Default | Write-Host
    Write-Output "Get keys list completed"

    foreach ( $keyValues in $responseX )
    {
        if ( $keyValues.title = $keyName )
        {
            $keyId = $keyValues.id
        }
    }
    # Delete the existing key if it exists
    if ( ![string]::IsNullOrEmpty( $keyId ) )
    {
        Write-Output "Delete existing key"
        # curl -u "lansaeval%%N:LanSA(122)" -X "DELETE" https://api.github.com/user/keys/%PUBKEYID%
        $url = "https://api.github.com/user/keys/" + $keyId
        $response = Invoke-WebRequest -Method DELETE -uri $url -Headers $headers -UseBasicParsing
        $response.content | Out-String | ConvertFrom-Json | Out-Default | Write-Host
    }
    # Add the key
    Write-Output "Add key"
    # rem curl -u "lansaeval%%N:LanSA(122)" --data "{\"title\":\"lansaeval122\",\"key\":\"%NEWPUBKEY%\"}" https://api.github.com/user/keys
    $key = Get-Content $sshKeyFile -Raw
    $body = @{"title"="lansaeval122"; "key"="$key"} | ConvertTo-Json
    $response = Invoke-WebRequest -uri "https://api.github.com/user/keys" -Headers $headers -Method POST -ContentType "application/json" -Body $body -UseBasicParsing
    $response.content | Out-String | ConvertFrom-Json | Out-Default | Write-Host
} catch {
    $_ | Out-Default | Write-Host
    $e = $_.Exception
    $e | format-list -force | Out-Default | Write-Host
    Write-Host( "Configuration of $userid failed" )
    cmd /c exit -1 | Write-Host    #Set $LASTEXITCODE
    Write-Host( "LASTEXITCODE $LASTEXITCODE" )
    return
} finally {
    Pop-Location
}
Write-Host( "Configuration of $userid succeeded" )