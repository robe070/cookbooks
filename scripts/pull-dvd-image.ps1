param (
    [Parameter(Mandatory=$true)]
    [string]
    $S3DVDImageDirectory,

    [Parameter(Mandatory=$true)]
    [string]
    $DvdDir,

    [Parameter(Mandatory=$true)]
    [string]
    $SQLServerInstalled
)

Write-Output "$(Log-Date) S3DVDImageDirectory = $S3DVDImageDirectory, DvdDir = $DvdDir"

if ( $SQLServerInstalled -eq $false) {
    cmd /c aws s3 sync  $S3DVDImageDirectory $DvdDir "--exclude" "*ibmi/*" "--exclude" "*AS400/*" "--exclude" "*linux/*" "--delete" | Write-Output
} else {
    cmd /c aws s3 sync  $S3DVDImageDirectory $DvdDir "--exclude" "*ibmi/*" "--exclude" "*AS400/*" "--exclude" "*linux/*" "--exclude" "*setup/Installs/MSSQLEXP/*" "--delete" | Write-Output
}
