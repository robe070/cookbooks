param(
    [Parameter(Mandatory=$true)]
    [String]
    $Language,

    [Parameter(Mandatory=$true)]
    [String]
    $Platform
)
switch ( $Platform) {
    "win2016" {
        switch ( $Language ) {
            "jpn" {
                Write-Host( "Set the language used by the user to Japanese")
                Set-WinUserLanguageList -LanguageList ja-JP,en-US -Force

                Write-Host( "Overwrite the input language with Japanese" )
                Set-WinDefaultInputMethodOverride -InputTip "0411:00000411"

                Write-Host( "Set the input method to MS-IME.")
                Set-WinLanguageBarOption -UseLegacySwitchMode -UseLegacyLanguageBar
            }
        }
    }
    "win2019" {
        switch ( $Language ) {
            "jpn" {
                Write-Host( "Set the language used by the user to Japanese")
                Set-WinUserLanguageList -LanguageList ja-JP,en-US -Force

                Write-Host( "Overwrite the input language with Japanese" )
                Set-WinDefaultInputMethodOverride -InputTip "0411:00000411"

                Write-Host( "Set the input method to MS-IME.")
                Set-WinLanguageBarOption -UseLegacySwitchMode -UseLegacyLanguageBar
            }
        }
    }
}

Restart-Computer