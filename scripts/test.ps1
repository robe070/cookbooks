$env:Path += ';C:\Program Files (x86)\\Git\\cmd'
cd \lansa
cmd /c git checkout -f master '2>&1'
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 128) {Write-Error ('Git clone failed');exit $LastExitCode};
exit 21


  invoke-command  -Session $session -ScriptBlock { $ENV:path }

  Add-DirectoryToEnvPathOnce -Directory c:\rob
  $ENV:PATH
