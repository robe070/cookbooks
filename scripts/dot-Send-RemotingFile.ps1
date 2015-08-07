#requires -version 2.0


function Initialize-TempScript ($Path) {
    "<# DATA" | Set-Content -Path $Path 
}

function Complete-Chunk () {
@"
DATA #>
`$TransferPath = `$Env:TEMP | Join-Path -ChildPath '$TransferId'
`$InData = `$false
`$WriteStream = [IO.File]::OpenWrite(`$TransferPath)
try {
    `$WriteStream.Seek(0, 'End') | Out-Null
    `$MyInvocation.MyCommand.Definition -split "``n" | ForEach-Object {
        if (`$InData) {
            `$InData = -not `$_.StartsWith('DATA #>')
            if (`$InData) {
                `$WriteBuffer = [Convert]::FromBase64String(`$_)
                `$WriteStream.Write(`$WriteBuffer, 0, `$WriteBuffer.Length)
            }
        } else {
            `$InData = `$_.StartsWith('<# DATA')
        }
    }
} finally {
    `$WriteStream.Close()
}
"@
}

function Complete-FinalChunk ($Destination) {
@"
`$TransferPath | Move-Item -Destination '$Destination' -Force
"@
}

function Send-RemotingFile{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Runspaces.PSSession]
        $Session,

        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter(Mandatory=$true)]
        [string]
        $Destination,
    
        [int]
        $TransferChunkSize = 0x10000
    )

    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest

    $EncodingChunkSize = 57 * 100
    if ($EncodingChunkSize % 57 -ne 0) {
        throw "EncodingChunkSize must be a multiple of 57"
    }

    $TransferId = [Guid]::NewGuid().ToString()


    $Path = ($Path | Resolve-Path).ProviderPath
    $ReadBuffer = New-Object -TypeName byte[] -ArgumentList $EncodingChunkSize

    $TempPath = ([IO.Path]::GetTempFileName() | % { $_ | Move-Item -Destination "$_.ps1" -PassThru}).FullName
    $ReadStream = [IO.File]::OpenRead($Path)

    $ChunkCount = 0
    Initialize-TempScript -Path $TempPath 

    $TransferIndex = 0
    try {
        do {
            $ReadCount = $ReadStream.Read($ReadBuffer, 0, $EncodingChunkSize)
            if ($ReadCount -gt 0) {
                [Convert]::ToBase64String($ReadBuffer, 0, $ReadCount, 'InsertLineBreaks') |
                    Add-Content -Path $TempPath
            }
            $ChunkCount += $ReadCount
            if ($ChunkCount -ge $TransferChunkSize -or $ReadCount -eq 0) {
                # send
                Write-Verbose "Sending chunk $TransferIndex"
                Complete-Chunk | Add-Content -Path $TempPath
                if ($ReadCount -eq 0) {
                    Complete-FinalChunk -Destination $Destination | Add-Content -Path $TempPath
                    Write-Verbose "Sending final chunk"
                }
                Invoke-Command -Session $Session -FilePath $TempPath 
            
                # reset
                $ChunkCount = 0
                Initialize-TempScript -Path $TempPath 

                $TransferIndex++
            }
        } while ($ReadCount -gt 0)
    } finally {
        if ($ReadStream) { $ReadStream.Close() }
        # $Session | Remove-PSSession
        $TempPath | Remove-Item
    }

}