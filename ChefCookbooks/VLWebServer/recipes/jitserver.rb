# LANSA JIT server

# We'll copy it to a "normal" directory rather than the default download location under the %USERPROFILE% directory
# because our deployment packages have issues with the default permissions on the %USERPROFILE% directory.

remote_file "c:/temp/CLOUDJIT_v1.0.1_en-us.msi" do
   source 'https://s3-ap-southeast-2.amazonaws.com/lansa/uploads/CLOUDJIT_v1.0.1_en-us.msi'
end

windows_package "LANSA JIT server" do
#   source 'https://s3-ap-southeast-2.amazonaws.com/lansa/uploads/CLOUDJIT_v1.0.1_en-us.msi'
   source 'c:\temp\CLOUDJIT_v1.0.1_en-us.msi'
   options 'APPA="c:\LANSA\JITServer" HOSTROUTEPORTNUMBER=4550'
   installer_type :msi
   action :install
end
