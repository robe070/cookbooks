# Refresh access to GitHub Personal Access Tokens.
# PATs expire after a year of not being used. So use them more frequently than that and they don't expire
# LanSA(122)
Param(
    [Parameter(Mandatory=$false)]
        [ValidateSet('Live','Test','Dev','All', '207')]
        [string] $StackType = 'All'
)

function TestGitHubPATAccess{
    Param(
        [Parameter(Mandatory)] [string] $Userid,
        [Parameter(Mandatory)] [string] $Password
    )
    $credentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($userid + ":" + $password))
    $headers = @{ 'Authorization' = "basic $Credentials" }

    # curl -u "userid:password" https://api.github.com/user
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $response = Invoke-WebRequest -uri "https://api.github.com/user" -Headers $headers -UseBasicParsing

    $responseX = $response.content | Out-String | ConvertFrom-Json
    $responseX.login | out-default | Write-Host

    # curl -u "userid:password" https://api.github.com/user/keys
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $response = Invoke-WebRequest -uri "https://api.github.com/user/keys" -Headers $headers -UseBasicParsing

    $responseX = $response.content | Out-String | ConvertFrom-Json
    $responseX | out-default | Write-Host
}
try
{
    $PasswordPath = '\\lansasrvnewer\lansa\FreeTrialGitHubPasswords.csv'
    Write-Host("Get the password from $PasswordPath")
    $PasswordFile = Import-Csv ($PasswordPath)

    if ( $StackType -eq 'All' ) {
        Foreach ($passwordEntry in $PasswordFile) {
            TestGitHubPATAccess $passwordEntry.repo $passwordEntry.pat
        }
    } else {
        [Decimal]$EnvironmentStart=0
        [Decimal]$EnvironmentEnd=0
        [Decimal]$Environment=0
        [System.Collections.ArrayList]$Environmentlist = @()

        switch ( $StackType ) {
            {$_ -eq 'Live'} {
                $EnvironmentStart = 10
                $EnvironmentEnd = 109
            }
            {$_ -eq 'Test'} {
                $EnvironmentStart = 200
                $EnvironmentEnd = 209
            }
            {$_ -eq 'Dev'} {
                $EnvironmentStart = 300
                $EnvironmentEnd = 309
            }
            # Handle numeric entry
            Default {
                [Decimal] $EnvironmentNum = [Decimal] $_
                $EnvironmentStart = $EnvironmentNum
                $EnvironmentEnd = $EnvironmentNum
            }
        }

        For ( $Environment = $EnvironmentStart; $Environment -le $EnvironmentEnd; $Environment++) {
            $Environmentlist.add($Environment) | Out-Null
        }

        if ( $Environmentlist.Count -eq 0 ) {
            throw "There are no environments requested"
        }

        Write-Host( "Environment List: $($Environmentlist -join ',')")

        $PasswordMap = @{}
        $PasswordFile | foreach { $PasswordMap[$_.repo] = $_.pat }


        foreach ($Environment in $Environmentlist) {
            $userid = "lansaeval" + $Environment
            if ( $passwordMap.ContainsKey( $userid) ) {
                $password = $passwordMap[$userid]
                TestGitHubPATAccess $userid $password
            } else {
                throw "$userid does not have a PAT in $PasswordPath"
            }
        }
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