# Refresh access to GitHub Personal Access Tokens.
# PATs expire after a year of not being used. So use them more frequently than that and they don't expire
# LanSA(122)
try
{
    $PasswordPath = '\\lansasrvnewer\lansa\FreeTrialGitHubPasswords.csv'
    Write-Host("Get the password from $PasswordPath")
    $PasswordFile = Import-Csv ($PasswordPath)

   Foreach ($passwordEntry in $PasswordFile) {
        $userid = $passwordEntry.repo
        $password = $passwordEntry.pat
        #Write-Host("Repository: userid:$password" )

        $credentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($userid + ":" + $password))
        $headers = @{ 'Authorization' = "basic $Credentials" }

        # curl -u "userid:password" https://api.github.com/user
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $response = Invoke-WebRequest -uri "https://api.github.com/user" -Headers $headers -UseBasicParsing

        $responseX = $response.content | Out-String | ConvertFrom-Json
        $responseX.login | out-default | Write-Host
   }
}
catch
{
   $_ | Out-Default | Write-Host
   $e = $_.Exception
   $e | format-list | Out-Default | Write-Host
   Write-Host( "Refresh failed" )
   cmd /c exit -1
   Write-Host( "LASTEXITCODE $LASTEXITCODE" )
   return
}
Write-Host( "Refresh of PAT access succeeded" )