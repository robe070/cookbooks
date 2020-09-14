try
{
   $envId = $args[0]
   $pwd = $args[1]
   #$sshKeyFileLocation = $args[2]
   #$envId = 207
   #$pwd = "LanSA(122)"
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
      Rename-Item -path $sshKeyDirectory -newName $backupDir
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
   #ssh-keygen.exe --% -t rsa -b 4096 -C lansaeval$envId@lansa.com -N "" -f lansaeval122_rsa
   $p = start-process -wait -PassThru -nonewwindow ssh-keygen -argumentlist "-t rsa -b 4096 -C lansaeval$envId@lansa.com -N `"`" -f lansaeval122_rsa"
    if ( -not [string]::IsNullOrEmpty($p.ExitCode) -and ($p.ExitCode -ne 0) ) 
    {
       $ExitCode = $p.ExitCode
       throw "ssh-gen returned error code $($p.ExitCode)."
    }
   
   Write-Output "Key Gen completed"

   $credentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($userid + ":" + $pwd))
   $headers = @{ 'Authorization' = "Basic $credentials" }

   #Get the key's id. Need it for the DELETE. Be nice if you could just give the name which to my knowledge is unique.
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   Write-Output "Get keys list"
   # curl -u "lansaeval207:LanSA(122)" https://api.github.com/user/keys 
   $response = Invoke-WebRequest -uri "https://api.github.com/user/keys" -Headers $headers -UseBasicParsing
   $responseX = $response.content | Out-String | ConvertFrom-Json

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
      $responseX = $response.content | Out-String
   }

   # Add the key
   Write-Output "Add key"
   # rem curl -u "lansaeval%%N:LanSA(122)" --data "{\"title\":\"lansaeval122\",\"key\":\"%NEWPUBKEY%\"}" https://api.github.com/user/keys
   $key = Get-Content $sshKeyFile -Raw 
   $body = @{"title"="lansaeval122"; "key"="$key"} | ConvertTo-Json
   $response = Invoke-WebRequest -uri "https://api.github.com/user/keys" -Headers $headers -Method POST -ContentType "application/json" -Body $body -UseBasicParsing
   $responseX = $response.content | Out-String
}
catch 
{
   $_
        
   $e = $_.Exception
   $e | format-list -force

   Write-Host( "Configuration failed " )

   cmd /c exit -1 | Write-Host    #Set $LASTEXITCODE
   Write-Host( "LASTEXITCODE $LASTEXITCODE" )
   return
}

cmd /c exit 0 | Write-Host    #Set $LASTEXITCODE

Write-Host( "Configuration succeeded" )
