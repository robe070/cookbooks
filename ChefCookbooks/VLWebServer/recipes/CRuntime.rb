# C++ Redistributable

windows_package "C Redistributable" do
   source 'https://s3-ap-southeast-2.amazonaws.com/lansa/uploads/vcredist_x86.exe'
   options '/q'
   installer_type :custom
   action :install
end

windows_package "C Redistributable" do
   source 'https://s3-ap-southeast-2.amazonaws.com/lansa/uploads/vcredist_x64.exe'
   options '/q'
   installer_type :custom
   action :install
end

# Must use "sysnative" because chef-client is a 32 bit app and so will redirect any System32
# references to SysWOW64.
# http://serverfault.com/questions/567597/chef-not-deleting-files-in-systemroot-system32-path-using-file-resource
remote_directory "#{ENV['SystemRoot']}\\sysnative" do
  source "CRuntimeDebug/x64"
  action :create
  purge true
end

remote_directory "#{ENV['SystemRoot']}\\SysWOW64" do
  source "CRuntimeDebug/x86"
  action :create
  purge true
end
