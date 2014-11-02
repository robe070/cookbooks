# C++ Redistributable

windows_package "C Redistributable" do
   source 'https://s3-ap-southeast-2.amazonaws.com/lansa/uploads/vcredist_x86.exe'
   options '/q'
   installer_type :custom
   action :install
end
