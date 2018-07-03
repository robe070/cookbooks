# Call the Vl Web Test server module through the load balancer

# Could be improved:
# 1) Also run the web page too - xvlwebtst
# 2) Run against EVERY instance in a stack, not just the one the LB sends it too.
#    Requires enumerating the ASG and obtaining the DNS of each instance.

'CheckVLWebStatus.ps1'

$script:IncludeDir = $null
if ( !$script:IncludeDir)
{
    # Log-Date can't be used yet as Framework has not been loaded

	Write-Host "Initialising environment - presumed not running through RemotePS"
	$MyInvocation.MyCommand.Path
	$script:IncludeDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\scripts'
    Write-Host "Include path $script:IncludeDir"
	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else
{
	Write-Output "$(Log-Date) Environment already initialised"
}

Write-Output "$(date) AEST"

$a = Get-Date
Write-Host "$($a.ToUniversalTime()) UTC"

try {
    $404count = 0
    $500count = 0
    $defaultcount = 0
    $StackStart = 1
    $StackEnd = 9
    [System.Collections.ArrayList]$stacklist = @()
    For ( $stack = $StackStart; $stack -le $StackEnd; $stack++) {
        $stacklist.add($stack) | Out-Null 
    }
    $stacklist.add(10) | Out-Null
    $stacklist.add(20) | Out-Null
    $stacklist.add(30) | Out-Null

    $StackError = $false
    Foreach ( $stack in $stacklist) {
        Write-Host "Stack $stack"
        if ( $stack -eq 20 ) {
            $max = 5
        } else {
            $max = 10
        }
        for ( $appl = 1; $appl -le $max; $appl++ ) {
            try {
                $url = "https://eval$stack.paas.lansa.com/app$appl/lansaweb?w=XVLSMTST&r=GETRESPONSE&vlweb=1&part=dem&lang=ENG"
                $response = Invoke-WebRequest -Uri $url
                $ResponseCode = $response.StatusCode
                switch ($ResponseCode) {
                    200 { }
                    404 { Write-FormattedOutput "$ResponseCode Stack $stack App $appl $url" -ForegroundColor 'red' | Out-Host; $StackError = $true; $404count++ }
                    500 { Write-FormattedOutput "$ResponseCode Stack $stack App $appl $url" -ForegroundColor 'yellow' | Out-Host; $StackError = $true; $500count++ }
                    default { Write-FormattedOutput"$ResponseCode Stack $stack App $appl $url" -ForegroundColor 'orange' | Out-Host; $StackError = $true; $defaultcount++ }
                }                  
            } catch {
                $StackError = $true
                $ResponseCode = $_.Exception.Response.StatusCode.Value__
                switch ($ResponseCode) {
                    404 { Write-FormattedOutput "$ResponseCode Stack $stack App $appl $url" -ForegroundColor 'red' | Out-Host; $404count++ }
                    500 { Write-FormattedOutput "$ResponseCode Stack $stack App $appl $url" -ForegroundColor 'yellow' | Out-Host; $500count++ }
                    default { Write-FormattedOutput "$ResponseCode Stack $stack App $appl $url" -ForegroundColor 'orange' | Out-Host; $defaultcount++ }
                }               
            }
        }
    }
} catch {
    $_
} finally {
    If ( !$StackError ) {
        Write-GreenOutput "All Apps in stacks $StackStart to $StackEnd in service " | Out-Host
    } else {
        Write-Output "" | Out-Host
        if ( $404count -gt 0 -or $defaultcount -gt 0  ) {
            Write-RedOutput "Test failed"  | Out-Host
        }
        if ( $404count -gt 0 ){ Write-RedOutput "404 usually means the Listener is not running this is important to fix ASAP. And its simple to fix. Just re-deploy the app"}
        if ( $500count -gt 0 ){ Write-FormattedOutput "500 usually means Free Trial was installed but no app was deployed. Look at git repo and check that there is just the one commit. If thats the case then this error may be ignored." -ForegroundColor 'yellow'}
        if ( $defaultcount -gt 0 ){ Write-FormattedOutput "Other response codes have unknown cause" -ForegroundColor 'orange'}
    }
}
