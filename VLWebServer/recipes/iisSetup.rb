#
# Cookbook Name:: learn_chef_iis
# Recipe:: default
#
# Copyright (c) 2014 The Authors, All Rights Reserved.
powershell_script 'Install IIS' do
  code 'Add-WindowsFeature Web-Server'
  guard_interpreter :powershell_script
  not_if "(Get-WindowsFeature -Name Web-Server).Installed"
end

service 'w3svc' do
  action [:start, :enable]
end

template 'c:\inetpub\wwwroot\Default.htm' do
  source 'index.html.erb'
end

# var1 = node['platform']
# log "Hi #{var1} !!!!!!!!!!!!"
# log "Hi #{node['platform']} !!!!!!!!!!!!"
