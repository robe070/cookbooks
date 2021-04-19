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
                $lpurl = "https://lansa.s3-ap-southeast-2.amazonaws.com/3rd+party/Japanese+Language+Packs/Server+2016/jpn/x64fre_Server_ja-jp_lp.cab"
                $langcode = "ja-JP"
            }
        }
    }
    "win2019" {
        switch ( $Language ) {
            "jpn" {
                $lpurl = "https://lansa.s3-ap-southeast-2.amazonaws.com/3rd+party/Japanese+Language+Packs/Server+2019/jpn/Microsoft-Windows-Server-Language-Pack_x64_ja-jp.cab"
                $langcode = "ja-JP"
            }
        }
    }
}
$lppath = "$ENV:temp\lang-pack.cab"
Write-Host( "Download $lpurl to $lppath")
Invoke-WebRequest -Uri $lpurl -OutFile $lppath

Write-Host( "Install the Japanese language Pack using the Lpksetup.exe command. Forces a reboot after installation" )
C:\windows\system32\Lpksetup.exe /i $langcode /f /s /p $lppath