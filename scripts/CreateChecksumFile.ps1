function CreateChecksumFile
{
    param (
        [Parameter(Mandatory=$true)]
            [string]
            $Algorithm,
    
        [Parameter(Mandatory=$true)]
            [String[]] 
            $FilePath
    )
    $Exec = "S:\Kelvin\util\nt\x64\$($Algorithm).exe"
    
    $files = Get-ChildItem $FilePath 
    foreach ($file in $files ) {
        $file.Name
        $Result = &$Exec $file
        $Result
        $split = $Result -split(" \(")
        $Algorithm = $split[0]
        $split2 = $split[1] -split("\) = ")
        $FileChecked = $split2[0]
        $Checksum = $split2[1]
        $Algorithm
        $FileChecked
        $Checksum
        New-Item "$($FileChecked)_$Checksum.$Algorithm" -ItemType file -Force
    }
}

# Example execution...
# CreateChecksumFile md5 '.\post-ide-boot.ps1'