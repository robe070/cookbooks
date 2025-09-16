# SetVersionVariables.ps1
# This script queries all the artefacts published by Build Image Release Artefacts pipeline
# so that they may be used instead of the pipeline variables used previously. Thus the
# pipeline does not need to be configured to run the tests.
# It automatically works out which tests to run based on the artefacts available.
#
param (
    [Parameter(Mandatory=$true)]
    [string]
    $AwsTemplateRepoPath
)
Write-Host "Set all pipeline variables to false"
Write-Host "These variables may be accessed in any subsequent stage or job in the pipeline."
Write-Host "The current stage or job needs to be explicitly dependent on the stage or job that sets them."
Write-Host "You refer to them as $[stageDependencies.<StageName>.<JobName>.outputs['<StepName>.Build-w19d-15-0']]"
Write-Host "e.g. $[stageDependencies.Init.Init.outputs['vars.Build-w19d-15-0']]"
Write-Host "The template include file vars.yml maps each of the stageDependencies variables into environment variables."
Write-Host "Include the template file vars.yml in the Stage of your pipeline that needs to use these variables in the jobCondition."
Write-Host "You refer to them in your scripts as `$(Build-w19d-15-0), `$(Build-w19d-15-0j), etc."

Write-Host "##vso[task.setvariable variable=Build-w19d-15-0;isOutput=true]False"
Write-Host "##vso[task.setvariable variable=Build-w19d-15-0j;isOutput=true]False"
Write-Host "##vso[task.setvariable variable=Build-w19d-16-0;isOutput=true]False"
Write-Host "##vso[task.setvariable variable=Build-w19d-16-0j;isOutput=true]False"

Write-Host "##vso[task.setvariable variable=Build-w22d-15-0;isOutput=true]False"
Write-Host "##vso[task.setvariable variable=Build-w22d-15-0j;isOutput=true]False"
Write-Host "##vso[task.setvariable variable=Build-w22d-16-0;isOutput=true]False"
Write-Host "##vso[task.setvariable variable=Build-w22d-16-0j;isOutput=true]False"

Write-Host "##vso[task.setvariable variable=Build-w25d-15-0;isOutput=true]False"
Write-Host "##vso[task.setvariable variable=Build-w25d-15-0j;isOutput=true]False"
Write-Host "##vso[task.setvariable variable=Build-w25d-16-0;isOutput=true]False"
Write-Host "##vso[task.setvariable variable=Build-w25d-16-0j;isOutput=true]False"

$path = "$($env:Pipeline_Workspace)/_Build Image Release Artefacts/aws"
Write-Host "Using $path"
if (Test-Path $path) {
    try{
        Write-Host("Locate any files in the path $path")
        # Get all .txt files matching the pattern w??d-??-?*.txt
        # Sort them with the latest windows version and lansa version first e.g. w25d... is before w22d...
        $files = Get-ChildItem -Path $path -Filter "*.txt" |
            Where-Object { $_.BaseName -match '^w\d{2}d-\d{2}-\d{1}.*' } | Sort-Object -Property Name -Descending

        foreach ($file in $files) {
            $buildName = $file.BaseName  # e.g., "w19d-15-0"
            $varName = "Build-$buildName"
            Write-Host "##vso[task.setvariable variable=$varName;isOutput=true]True"
        }
    } catch{
        $_ | Out-Default | Write-Host
        Throw "Failed to set pipeline build Variables"
    }
} else {
    Write-Host "Artifact path $path does NOT exist"
}