function CreateChecksumFile
{
    param (
        [Parameter(Mandatory=$true)]
            [string]
            $Algorithm,
    
        [Parameter(Mandatory=$true)]
            [String] 
            $FilePath,
            
        [Parameter(Mandatory=$false)]
            [boolean] 
            $Target = $false
    )
    $Exec = "s:\Kelvin\util\nt\x64\$($Algorithm).exe"
    
    if ( -not (Test-Path $Exec) ) {
        # Can't access the network so presume we are in a remote session where network access is not available
        
        # Presume its in the current directory
        $Exec = "$Script:ScriptDir\$($Algorithm).exe"    
        if ( -not (Test-Path $Exec )) {
            # And further, presume the checksum exe is in the path
            $Exec = "$($Algorithm).exe"    
        }
    }
    $exec
    
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
        $AlgoFileName = "$($FileChecked)_$Checksum.$Algorithm" 
        if ( $Target) {
            $AlgoFileName += '.tgt'
        }
        New-Item $AlgoFileName -ItemType file -Force
    }
}
