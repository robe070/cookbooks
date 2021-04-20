param(
    [Parameter(Mandatory=$true)]
    [String]
    $Language,

    [Parameter(Mandatory=$true)]
    [String]
    $Platform
)
Write-Host("Configure Japanese localization settings")
switch ( $Platform) {
    "win2016" {
        switch ( $Language ) {
            "jpn" {
                Write-Host( "Overwrite the UI language with Japanese")
                Set-WinUILanguageOverride -Language ja-JP

                Write-Host( "Make the time / date format the same as the Windows language")
                Set-WinCultureFromLanguageListOptOut -OptOut $False

                Write-Host( "Set the location to Japan")
                # Is this appropriate? This image may be started in any region of the world. What does it mean to be 'in Japan' when you may be running anywhere?
                Set-WinHomeLocation -GeoId 0x7A

                Write-Host( "Set the system locale to Japan")
                Set-WinSystemLocale -SystemLocale ja-JP

                Write-Host( "Leave timezone as UTC")
                # Set-TimeZone -Id "Tokyo Standard Time"
            }
        }
    }
    "win2019" {
        switch ( $Language ) {
            "jpn" {
                Write-Host( "Overwrite the UI language with Japanese")
                Set-WinUILanguageOverride -Language ja-JP

                Write-Host( "Make the time / date format the same as the Windows language")
                Set-WinCultureFromLanguageListOptOut -OptOut $False

                Write-Host( "Set the location to Japan")
                # Is this appropriate? This image may be started in any region of the world. What does it mean to be 'in Japan' when you may be running anywhere?
                Set-WinHomeLocation -GeoId 0x7A

                Write-Host( "Set the system locale to Japan")
                Set-WinSystemLocale -SystemLocale ja-JP

                Write-Host( "Leave timezone as UTC")
                # Set-TimeZone -Id "Tokyo Standard Time"
            }
        }
    }
}

Restart-Computer