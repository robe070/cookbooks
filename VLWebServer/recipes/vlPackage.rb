# C++ redistributable
windows_package "C Redistributable" do
   source 'c:\temp\vcredist_x86.exe'
   options '/q'
   installer_type :custom
   action :install
end
