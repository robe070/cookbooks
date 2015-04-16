<#
.SYNOPSIS

Set the X_RUN global environment variable. Principally used to set the tracing flags

1. Stops the listener and all web jobs.
2. Set the environment variable
3. Restarts the Listener

.EXAMPLE

#>
param(
[String]$x_run='ITRO=N ITRL=4 ITRM=999999999'
)

# Put first output on a new line in cfn_init log file
Write-Output ("`n")

# $DebugPreference = "Continue"

Write-Output ("x_run = $x_run")

# Stop all Listeners and all web jobs
Stop-Service -Name 'lconnect Services*' -Force -PassThru
kill -Name w3_p1200 -Force -ErrorAction SilentlyContinue
kill -Name w3_p2000 -Force -ErrorAction SilentlyContinue

[Environment]::SetEnvironmentVariable("X_RUN", $x_run, "Machine")

# Restart all Listeners
Start-Service -Name 'lconnect Services*' -PassThru