# C++ Redistributable

windows_package "C Redistributable" do
   source 'https://s3-ap-southeast-2.amazonaws.com/lansa/uploads/CRuntime2010/vcredist2010_x86.exe'
   options '/q'
   installer_type :custom
   action :install
end

windows_package "C Redistributable" do
   source 'https://s3-ap-southeast-2.amazonaws.com/lansa/uploads/CRuntime2010/vcredist2010_x64.exe'
   options '/q'
   installer_type :custom
   action :install
end

windows_package "C Redistributable" do
   source 'https://s3-ap-southeast-2.amazonaws.com/lansa/uploads/CRuntime2012/vcredist2012_x86.exe'
   options '/q'
   installer_type :custom
   action :install
end

windows_package "C Redistributable" do
   source 'https://s3-ap-southeast-2.amazonaws.com/lansa/uploads/CRuntime2012/vcredist2012_x64.exe'
   options '/q'
   installer_type :custom
   action :install
end

windows_package "C Redistributable" do
   source 'https://s3-ap-southeast-2.amazonaws.com/lansa/uploads/CRuntime2013/vcredist2013_x86.exe'
   options '/q'
   installer_type :custom
   action :install
end

windows_package "C Redistributable" do
   source 'https://s3-ap-southeast-2.amazonaws.com/lansa/uploads/CRuntime2013/vcredist2013_x64.exe'
   options '/q'
   installer_type :custom
   action :install
end

# Must use "sysnative" because chef-client is a 32 bit app and so will redirect any System32
# references to SysWOW64.
# http://serverfault.com/questions/567597/chef-not-deleting-files-in-systemroot-system32-path-using-file-resource
#remote_directory "#{ENV['SystemRoot']}\\sysnative" do
#  source "CRuntimeDebug/x64"
#  action :create
#  purge true
#end

#remote_directory "#{ENV['SystemRoot']}\\SysWOW64" do
#  source "CRuntimeDebug/x86"
#  action :create
#  purge true
#end

cookbook_file "mfc100d.dll" do
  source "CRuntimeDebug/x64/mfc100d.dll"
  path "#{ENV['SystemRoot']}\\sysnative\\mfc100d.dll"
end
cookbook_file "mfc100ud.dll" do
  source "CRuntimeDebug/x64/mfc100ud.dll"
  path "#{ENV['SystemRoot']}\\sysnative\\mfc100ud.dll"
end
cookbook_file "mfcm100d.dll" do
  source "CRuntimeDebug/x64/mfcm100d.dll"
  path "#{ENV['SystemRoot']}\\sysnative\\mfcm100d.dll"
end
cookbook_file "mfcm100ud.dll" do
  source "CRuntimeDebug/x64/mfcm100ud.dll"
  path "#{ENV['SystemRoot']}\\sysnative\\mfcm100ud.dll"
end
cookbook_file "msvcp100d.dll" do
  source "CRuntimeDebug/x64/msvcp100d.dll"
  path "#{ENV['SystemRoot']}\\sysnative\\msvcp100d.dll"
end
cookbook_file "msvcr100d.dll" do
  source "CRuntimeDebug/x64/msvcr100d.dll"
  path "#{ENV['SystemRoot']}\\sysnative\\msvcr100d.dll"
end

cookbook_file "mfc100d.dll" do
  source "CRuntimeDebug/x86/mfc100d.dll"
  path "#{ENV['SystemRoot']}\\SysWOW64\\mfc100d.dll"
end
cookbook_file "mfc100ud.dll" do
  source "CRuntimeDebug/x86/mfc100ud.dll"
  path "#{ENV['SystemRoot']}\\SysWOW64\\mfc100ud.dll"
end
cookbook_file "mfcm100d.dll" do
  source "CRuntimeDebug/x86/mfcm100d.dll"
  path "#{ENV['SystemRoot']}\\SysWOW64\\mfcm100d.dll"
end
cookbook_file "mfcm100ud.dll" do
  source "CRuntimeDebug/x86/mfcm100ud.dll"
  path "#{ENV['SystemRoot']}\\SysWOW64\\mfcm100ud.dll"
end
cookbook_file "msvcp100d.dll" do
  source "CRuntimeDebug/x86/msvcp100d.dll"
  path "#{ENV['SystemRoot']}\\SysWOW64\\msvcp100d.dll"
end
cookbook_file "msvcr100d.dll" do
  source "CRuntimeDebug/x86/msvcr100d.dll"
  path "#{ENV['SystemRoot']}\\SysWOW64\\msvcr100d.dll"
end
