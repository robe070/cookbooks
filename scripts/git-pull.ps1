param(
[String]$gitbranch
)
$newPath = 'C:\\Program Files (x86)\\Git\\cmd';
$oldPath = [Environment]::GetEnvironmentVariable('PATH', 'Machine');
$match = '*' + $newpath + '*';
$replace = $newPath + ';' + $oldPath;
if ( $oldpath -notlike $match )
{
    [Environment]::SetEnvironmentVariable('PATH', $replace, 'Machine');
    $env:Path += ';' + $newpath;
}
$env:Path;
cd \lansa;
cmd /C git fetch '2>&1';
if ($LASTEXITCODE -ne 0) {
    Write-Error ('Git fetch failed');
    exit $LastExitCode
};
cmd /C git checkout -f $gitbranch '2>&1'
if ($LASTEXITCODE -ne 0) {
    Write-Error ('Git checkout failed');
    exit $LastExitCode
};
cmd /C git pull origin '2>&1';
if ($LASTEXITCODE -ne 0) {
    Write-Error ('Git pull failed');
    exit $LastExitCode;
}

cmd /C exit 0
exit 0