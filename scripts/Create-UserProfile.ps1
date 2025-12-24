# Function to pre-create PCXUSER2 profile non-interactively
function Create-UserProfile {
    param (
        [string]$Username
    )

    # Get user SID
    $user = New-Object System.Security.Principal.NTAccount($Username)
    $sid = $user.Translate([System.Security.Principal.SecurityIdentifier]).Value

    # Add-Type for P/Invoke
    $signature = @'
[DllImport("userenv.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern int CreateProfile(
    string pszUserSid,
    string pszUserName,
    [Out] System.Text.StringBuilder pszProfilePath,
    uint cchProfilePath);
'@

    $userenv = Add-Type -MemberDefinition $signature -Name "UserEnv" -Namespace "Win32" -PassThru

    # Buffer for profile path (260 chars max)
    $profilePath = New-Object System.Text.StringBuilder(260)

    $result = $userenv::CreateProfile($sid, $Username, $profilePath, 260)

    if ($result -eq 0) {
        Write-Host "Profile created successfully at $($profilePath.ToString())"
    } else {
        $_
        $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Host "CreateProfile failed with error: $err"
    }
}

# Usage after PCXUSER2 creation and SeBatchLogonRight grant
Create-UserProfile -Username "PCXUSER2"