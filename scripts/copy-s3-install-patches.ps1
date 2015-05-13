<#
.SYNOPSIS

Copies all the patches in an S3 folder that are not yet in c:\lansa\oldpatches to c:\lansa\newpatches
All the patches in c:\lansa\newpatches are then executed in alphabetical order.
When complete, all the files in newpatches are copied to oldpatches.

.EXAMPLE


#>
param(
[String]$dbpassword = 'password',
[String]$webpassword = 'PCXUSER@122',
[String]$SUDB = '1',
[String]$bucket_name='lansa',
[String]$region='ap-southeast-2',
[String]$access_key,
[String]$secret_key,
[String]$folder='/change me',
[String]$target_dir= 'c:\lansa\newpatches',
[String]$old_dir= 'c:\lansa\oldpatches'
)

try
{
    if ( -not (Test-Path $old_dir) ) { New-Item -ItemType Directory -Force -Path $old_dir}
    if ( -not (Test-Path $target_dir) ) {New-Item -ItemType Directory -Force -Path $target_dir}

    [int]$InstalledPatchCount = 0

    # Clear-AWSCredentials -StoredCredentials lansa

    # Set-AWSCredentials -AccessKey $access_key -SecretKey $secret_key -StoreAs lansa
    # Initialize-AWSDefaults -ProfileName lansa -Region $region

    $FileList = Get-S3Object -BucketName $bucket_name -Key $folder
    $FileList | ft -AutoSize -Property Key,LastModified,Size, StorageClass| Out-String -stream | Write-Output
    foreach( $file in $FileList )
    {
        $patch_installed = $false
        $output = ($file.Key)

        # If not a directory, copy to c:\lansa\newpatches and install it.
        # Note that the directory structure is collapsed into a single directory - $target_dir.
        if ($file.size -ne 0)
        {
            # Just need patches
            if (  $file.key.ToLower().EndsWith( ".msp" ) )
            {
                # Get filename part of key
                [String[]] $filepaths = ($file.key -split '/' )

                [String] $filename = $filepaths[ $filepaths.length - 1]

                # Copy patch if filename is not in c:\lansa\oldpatches, and then install it
                if ( -not (Test-Path ( Join-Path -Path $old_dir -ChildPath $filename ) ) )
                {
                    $patch_installed = $true
                    $install_log = ( Join-Path -Path $ENV:TEMP -ChildPath "$filename.log" )

                    $output +=  (" - patch needs to be installed")
                    Write-Output $output

                    $s3key = $file.key
                    Write-Output ("Copying S3 item $bucket_name/$s3key to $target_dir")
                    $target_file = ( Join-Path -Path $target_dir -ChildPath $filename )
                    Read-S3Object -BucketName $bucket_name -Key $file.Key -File $target_file

                    # Install patch
                    $silentArgs = "/passive"
                    $additionalInstallArgs = "/lv*x $install_log", "PSWD=$dbpassword", "SUDB=$SUDB", "PASSWORDFORSERVICE=$webpassword"
                    Write-Output ("Running msiexec.exe /update $target_file $silentArgs $additionalInstallArgs")
                    $msiArgs = "/update `"$target_file`""
                    $msiArgs += " $silentArgs $additionalInstallArgs"
                    Start-Process -FilePath msiexec -ArgumentList $msiArgs -Wait

                    Write-Output ("See $install_log and other files in $ENV:TEMP for more details")

                    # Move target file to old
                    Write-Output ("Moving $target_file to $old_dir")
                    Move-Item -Path $target_file -Destination $old_dir -Force

                    $InstalledPatchCount +=1
                }
                else
                {
                    $output +=  (" - patch already installed")
                }
            }
            else
            {
                $output +=  (" - not a patch")
            }
        }
        else
        {
            $output += (" - directory ignored")
        }

        if ( -not $patch_installed )
        {
            Write-Output $output
        }
    }

    Clear-AWSCredentials -StoredCredentials lansa

    if ( $InstalledPatchCount -gt 0 )
    {
        Write-Output ("Patches installed successfully")
    }
    else
    {
        Write-Output ("No patches found")
    }
    exit 0
}
catch
{
    Write-Error ("Patching failed")
    exit 2
}