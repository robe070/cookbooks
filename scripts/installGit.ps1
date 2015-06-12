choco -y install git.install -version 1.9.4.20140929
cd \
$env:Path += ';C:\\Program Files (x86)\\Git\\cmd'
cmd /C git clone https://github.com/robe070/cookbooks.git lansa '2>&1'
cd \lansa
cmd /c git pull origin
Write-Output "Branch: $args[0]"
cmd /c git checkout -f $args[0]
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 128) {Write-Error ('Git clone failed');exit $LastExitCode};
