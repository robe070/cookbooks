# This has been renamed from default.rb because of a bug with Chef V12.1.x.
# It wont run default.rb.
include_recipe "VLWebServer::CRuntime"

features = %w{IIS-WebServerRole IIS-WebServer IIS-CommonHttpFeatures IIS-DefaultDocument IIS-DirectoryBrowsing IIS-HttpErrors IIS-StaticContent IIS-ApplicationDevelopment IIS-NetFxExtensibility IIS-NetFxExtensibility45 IIS-ASPNET IIS-ASPNET45 IIS-CGI IIS-ISAPIExtensions IIS-ISAPIFilter IIS-HealthAndDiagnostics IIS-HttpLogging IIS-RequestMonitor IIS-Security IIS-RequestFiltering IIS-Performance IIS-HttpCompressionStatic IIS-WebServerManagementTools IIS-ManagementConsole WAS-WindowsActivationService WAS-ProcessModel WAS-NetFxEnvironment WAS-ConfigurationAPI}

features.each do |feature|
  windows_feature feature do
    action :install
    all true
  end
end

# Run then disable Ec2ConfigMonitor
powershell_script "ProcessEc2ConfigMonitor" do
  code <<-EOH
    Enable-ScheduledTask -TaskName "Ec2ConfigMonitorTask"
    Start-ScheduledTask -TaskName "Ec2ConfigMonitorTask"
    Disable-ScheduledTask -TaskName "Ec2ConfigMonitorTask"
  EOH
end

include_recipe "VLWebServer::iisSetup2"
include_recipe "chocolatey"

chocolatey "gitextensions"

chocolatey "jre8"
