$hostname = 'robgw10\sqls17'
.\azure-custom-script.ps1 -server_name "$hostname" -dbname "AWAMAPP" -dbuser "sa" -dbpassword "Pcxuser@122robg" -webuser "PCXUSER2" -webpassword "Pcxuser@122robg" -MSIuri "c:\temp\15.0.msi"
