		$webuser = 'PCXUSER'
        $pkFile = 'C:\windows\Temp'
        $acl=Get-Acl -Path $pkFile
        $permission= $webuser,"Modify","Allow"
        $accessRule=new-object System.Security.AccessControl.FileSystemAccessRule $permission
        $acl.AddAccessRule($accessRule)
        Set-Acl $pkFile $acl
