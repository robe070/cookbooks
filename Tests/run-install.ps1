$ApplName = 'WEBSERVER'
$APPA = "${ENV:ProgramFiles(x86)}\$($ApplName)"
$installer_file = 'C:\dev\trunk\work\X_WIN95\X_LANSA\x_apps\WEBSERVR\WEBSERVR_v1.0.0_en-us.msi'
$server_name = 'ROBGW10'
$dbname = $ApplName
$GitRepoUrl = 'git@github.com:lansa/webserver.git'

[String[]] $Arguments = @( "/quiet /lv*x ${ENV:TEMP}\$ApplName.log", "SHOWCODES=1", "USEEXISTINGWEBSITE=1", "REQUIRES_ELEVATION=1", "DBUT=MSSQLS", "DBII=$($ApplName)", "DBSV=$server_name", "DBAS=$dbname", "TRUSTED_CONNECTION=1", "SUDB=1",  "USERIDFORSERVICE=PCXUSER2", "PASSWORDFORSERVICE=Pcxuser@122")

if ( $GitRepoUrl.Length -gt 0) {
    $Arguments += "GITREPOURL=$GitRepoUrl"
}    

Write-Output ("$(Log-Date) Arguments = $Arguments")

$x_err = (Join-Path -Path $ENV:TEMP -ChildPath 'x_err.log')
Remove-Item $x_err -Force -ErrorAction SilentlyContinue

Write-Output ("$(Log-Date) Installing LANSA")
$Arguments += "APPA=""$APPA"""
$p = Start-Process -FilePath $installer_file -ArgumentList $Arguments -Wait -PassThru

if ( $p.ExitCode -ne 0 ) {
    $ExitCode = $p.ExitCode
    $ErrorMessage = "MSI Install returned error code $($p.ExitCode)."
    Write-Error $ErrorMessage -Category NotInstalled
    throw $ErrorMessage
}

  