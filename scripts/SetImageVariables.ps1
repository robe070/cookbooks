# SetImageVariables.ps1
# This script sets the image variables for one ENG image or one JPN image.
param (
    [Parameter(Mandatory=$true)]
    [string]
    $AwsTemplateRepoPath,
    [Parameter(Mandatory=$true)]
    [boolean]
    $IsJPNImage
)
Write-Host "Set all pipeline variables to false"
Write-Host "These variables may be accessed in any subsequent stage or job in the pipeline."
Write-Host "The current stage or job needs to be explicitly dependent on the stage or job that sets them."
Write-Host "You refer to them as $[stageDependencies.<StageName>.<JobName>.outputs['<StepName>.Version']]"
Write-Host "e.g. $[stageDependencies.Init.Init.outputs['ENGImageVars.Version']]"
Write-Host "The template include file vars.yml maps each of the stageDependencies variables into environment variables."
Write-Host "Include the template file vars.yml in the Stage of your pipeline that needs to use these variables in the jobCondition."
Write-Host "You refer to them in your scripts as `$(Build-w19d-15-0), `$(Build-w19d-15-0j), etc."

Write-Host "##vso[task.setvariable variable=Stack;isOutput=true] "
Write-Host "##vso[task.setvariable variable=Version;isOutput=true] "
Write-Host "##vso[task.setvariable variable=VersionDigits;isOutput=true]0"
Write-Host "##vso[task.setvariable variable=ImageID;isOutput=true]ami-null"
Write-Host "##vso[task.setvariable variable=IsEnabled;isOutput=true]False"

$path = "$($env:Pipeline_Workspace)/_Build Image Release Artefacts/aws"
Write-Host "Using $path"
if (Test-Path $path) {
    try{
        $files = @()
        if ( $IsJPNImage ) {
            Write-Host("Locate any JPN images in the path $path")
            # Get all .txt files matching the pattern w??d-??-??j.txt
            # Sort them with the latest windows version and lansa version first e.g. w25d... is before w22d...
            $files = Get-ChildItem -Path $path -Filter "*.txt" |
                Where-Object { $_.BaseName -match '^w\d{2}r\d{1}d-\d{2}-\d{1}j$' } | Sort-Object -Property Name -Descending
        } else {
            Write-Host("Locate any ENG images in the path $path")
            # Get all .txt files matching the pattern w??d-??-?.txt
            # Sort them with the latest windows version and lansa version first e.g. w25d... is before w22d...
            $files = Get-ChildItem -Path $path -Filter "*.txt" |
                Where-Object { $_.BaseName -match '^w\d{2}r\d{1}d-\d{2}-\d{1}[^j]$' } | Sort-Object -Property Name -Descending
        }

        # Note: there may be 0 files
        if ($files.Count) {
            Write-Host "Files: $($files | ForEach-Object { $_.Name })"
            $buildName = $files[0].BaseName  # e.g., "w19d-15-0"
            $varName = "Build-$buildName"
            Write-Host "##vso[task.setvariable variable=$varName;isOutput=true]True"

            Write-Host "Now obtain the details of the build from the file $($file[0]). These variable values will be referred to using ENGImageVars.version, ENGImageVars.versionDigits, ENGImageVars.amiID, etc. Whereas within an individual stage they are referred to as Gate.version, etc. (Or JPN instead of ENG)"
            & "$AwsTemplateRepoPath\scripts\SetGateVariable.ps1" -BaseImageName "$buildName" -stackname 'RandomNameNotToBeUsed'
            break
        } else {
            Write-Host ("No files found")
        }
    } catch{
        $_ | Out-Default | Write-Host
        Throw "Failed to set pipeline image Variables"
    }
} else {
    Write-Host "Artifact path $path does NOT exist"
}