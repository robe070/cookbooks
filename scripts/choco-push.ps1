# Note that the -ApiKey does not work, it is arbitrary but MUST BE SPECIFIED!
# The PAT is created in AzureDevOps by logging in as the user and selecting the user settings wheel and Personal Access Token

Write-Host( "When run this script will prompt for the Username - enter rubbish - and the password - enter the PAT.")

# The kdiff3 package is no longer compatible with choco v2
# nuget push -Source "lansa" -ApiKey "arbitrary" C:\Users\Robert.SYD\Downloads\kdiff3.0.9.98.nupkg
nuget push -Source "lansa" -ApiKey "arbitrary" C:\Users\Robert.SYD\Downloads\chocolatey-core.extension.1.4.0.nupkg
nuget push -Source "lansa" -ApiKey "arbitrary" C:\Users\Robert.SYD\Downloads\DotNet4.5.2.4.5.2.20140902.nupkg
nuget push -Source "lansa" -ApiKey "arbitrary" C:\Users\Robert.SYD\Downloads\FoxitReader.2025.1.0.27937.nupkg
nuget push -Source "lansa" -ApiKey "arbitrary" C:\Users\Robert.SYD\Downloads\git.2.49.0.nupkg
nuget push -Source "lansa" -ApiKey "arbitrary" C:\Users\Robert.SYD\Downloads\git.install.2.49.0.nupkg
nuget push -Source "lansa" -ApiKey "arbitrary" C:\Users\Robert.SYD\Downloads\GoogleChrome.136.0.7103.93.nupkg
nuget push -Source "lansa" -ApiKey "arbitrary" C:\Users\Robert.SYD\Downloads\jre8.8.0.451.nupkg
nuget push -Source "lansa" -ApiKey "arbitrary" C:\Users\Robert.SYD\Downloads\vscode.1.100.2.nupkg
nuget push -Source "lansa" -ApiKey "arbitrary" C:\Users\Robert.SYD\Downloads\vscode.install.1.100.2.nupkg
