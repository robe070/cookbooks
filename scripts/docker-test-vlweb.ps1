$hostname = 'robgw10\sqls17'
.\azure-custom-script.ps1 -server_name "$hostname" -dbname "VLWEB" -dbuser "sa" -dbpassword "Pcxuser@122robg" -webuser "PCXUSER2" -webpassword "Pcxuser@122robg" -MSIuri "c:\temp\15.0-vlweb.msi"
