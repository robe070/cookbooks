Param(
    [Parameter(Mandatory)]
        [string] $StringToHash
)

# Create Input Data
$enc      = [system.Text.Encoding]::UTF8
$data     = $enc.GetBytes($StringToHash)

# Create a New SHA1 Crypto Provider
$sha1 = New-Object System.Security.Cryptography.SHA1CryptoServiceProvider

# Now hash and display results
$ResultHash = $sha1.ComputeHash($data)
$c = $null
Foreach ($element in $ResultHash) {$c = $c + [System.String]::Format("{0:X}", [System.Convert]::ToUInt32($element))}
Write-Host ""
$c
Write-Host "To check if this password is compromised enter the hash into this site: https://haveibeenpwned.com/Passwords"