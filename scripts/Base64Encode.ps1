
$SourceFile = 'c:\secrets\LANSAScalableLicense.pfx'
$B64File = 'c:\secrets\LANSAScalableLicense.txt'
$ReconstitutedFile = 'c:\secrets\LANSAScalableLicenseRecon.pfx'

[IO.File]::WriteAllBytes($B64File,[char[]][Convert]::ToBase64String([IO.File]::ReadAllBytes($SourceFile)))
[IO.File]::WriteAllBytes($ReconstitutedFile, [Convert]::FromBase64String([char[]][IO.File]::ReadAllBytes($B64File)))

$SourceFile = 'c:\secrets\LANSAIntegratorLicense.pfx'
$B64File = 'c:\secrets\LANSAIntegratorLicense.txt'
$ReconstitutedFile = 'c:\secrets\LANSAIntegratorLicenseRecon.pfx'

[IO.File]::WriteAllBytes($B64File,[char[]][Convert]::ToBase64String([IO.File]::ReadAllBytes($SourceFile)))
[IO.File]::WriteAllBytes($ReconstitutedFile, [Convert]::FromBase64String([char[]][IO.File]::ReadAllBytes($B64File)))

$SourceFile = 'c:\secrets\LANSADevelopmentLicense.pfx'
$B64File = 'c:\secrets\LANSADevelopmentLicense.txt'
$ReconstitutedFile = 'c:\secrets\LANSADevelopmentLicenseRecon.pfx'

[IO.File]::WriteAllBytes($B64File,[char[]][Convert]::ToBase64String([IO.File]::ReadAllBytes($SourceFile)))
[IO.File]::WriteAllBytes($ReconstitutedFile, [Convert]::FromBase64String([char[]][IO.File]::ReadAllBytes($B64File)))
