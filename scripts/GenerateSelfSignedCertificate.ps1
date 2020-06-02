Param(
    [Parameter(Mandatory)]
        [SecureString] $Pwd
)


$CertPath = 'cert:\localmachine\my'
$PfxPath = 'c:\appgwcert.pfx'
Remove-Item $PfxPath
$Cert = New-SelfSignedCertificate -certstorelocation cert:\localmachine\my -dnsname www.contoso.com
$cert

Export-PfxCertificate -cert "$CertPath\$($Cert.Thumbprint)" -FilePath $PfxPath -Password $pwd

[System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($PfxPath))