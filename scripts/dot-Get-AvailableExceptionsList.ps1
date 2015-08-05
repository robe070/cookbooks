function Get-AvailableExceptionsList {
    [CmdletBinding()]
    param()
    end {
        $CurrentDebugPreference = $DebugPreference
        $CurrentVerbosePreference = $VerbosePreference
        $DebugPreference = "SilentlyContinue"
        $VerbosePreference = "SilentlyContinue"
        # These irregular exceptions are probably due to not implementing the 4 parameter ErrorRecord constructor
        # Use of these exceptions could be implemented by 
        $irregulars = 'JobFailed|ProcessCommand|ServiceCommand|Amazon'
        # $irregulars = 'Dispose|OperationAborted|Unhandled|ThreadAbort|ThreadStart|TypeInitialization|Threading.Tasks.TaskSchedulerException|Threading.Tasks.UnobservedTaskExceptionEventArgs|Reflection.ReflectionTypeLoadException|Reflection.TargetInvocationException|ExceptionServices.HandleProcessCorruptedStateExceptionsAttribute|ExceptionServices.FirstChanceExceptionEventArgs|Text.DecoderExceptionFallback|Text.EncoderExceptionFallback|Reflection.Emit.ExceptionHandler|CodeDom.CodeThrowExceptionStatement|ComponentModel.LicenseException|Threading.ThreadExceptionEventArgs|Threading.ThreadExceptionEventHandler|Net.NetworkInformation.PingException|Forms.ThreadExceptionDialog|Drawing.Printing.InvalidPrinterException|Automation.JobFailedException|Windows.Controls.ExceptionValidationRule'
        [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
            if ( -not $_.Location ) {return}  # If there is no location then we go to next object
            Write-Debug ($_.Location)
            $_.GetExportedTypes() -match 'Exception' -notmatch $irregulars |
            Where-Object {
                $object = $_
                Write-Debug 'Getting Constructors'
                $_.GetConstructors()  -and 
                $( # Must have a default constructor
                    $allParams = $_.GetConstructors() | ForEach { 
                        ($_.GetParameters() | ForEach {$_.ToString()} ) -Join ", " 
                    } 
                    Write-Debug ($allParams | Format-List | Out-String)
                    if ( $allParams -and $allParams -notcontains '') { Write-Debug 'Begin';Write-Debug ($allParams | Format-List | Out-String);Write-Debug 'end'; return} 
                    $true
                ) -and
                $( # Must implement the exception interface System.Runtime.InteropServices._Exception
                    $allInterfaces = $object.GetInterfaces() | ForEach { 
                        (ForEach {$_.ToString()} )
                    } 
                    Write-Debug ($allInterfaces | Format-List | Out-String)
                    if ( -not $allInterfaces -or $allInterfaces -notcontains 'System.Runtime.InteropServices._Exception') { Write-Verbose 'Begin Bad Interfaces';Write-Verbose ($allInterfaces | Format-List | Out-String);Write-Verbose 'end'; return} 
                    Write-Debug ($object | Format-List | Out-String)
                    $true
                ) -and
                $(  Write-Verbose $object
                    $_exception = New-Object $object.FullName
                    New-Object Management.Automation.ErrorRecord $_exception, ErrorID, OpenError, Target
                )
            } | Select-Object -ExpandProperty FullName
        } 2> $null
        $DebugPreference = $CurrentDebugPreference
        $VerbosePreference = $CurrentVerbosePreference
    }

 <#  .Synopsis      Retrieves all available Exceptions to construct ErrorRecord objects.  .Description      Retrieves all available Exceptions in the current session to construct ErrorRecord objects.  .Example      $availableExceptions = Get-AvailableExceptionsList      Description      ===========      Stores all available Exception objects in the variable 'availableExceptions'.  .Example      Get-AvailableExceptionsList | Set-Content $env:TEMP\AvailableExceptionsList.txt      Description      ===========      Writes all available Exception objects to the 'AvailableExceptionsList.txt' file in the user's Temp directory.  .Inputs     None  .Outputs     System.String  .Link      New-ErrorRecord  .Notes      Name:      Get-AvailableExceptionsList      Author:    Robert Robelo      LastEdit:  08/24/2011 12:35  #>
}