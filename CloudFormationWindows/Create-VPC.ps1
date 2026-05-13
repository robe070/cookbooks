# PowerShell script to re-create a VPC and subnets in us-east-1 with proper tagging
# All resources will be tagged with Environment = "Lansa-Prod"
# Customize CIDR blocks, AZs, names, and any other values to match your original setup as closely as possible

# Ensure AWS Tools for PowerShell are installed and credentials are configured
# Set-DefaultAWSRegion -Region us-east-1   # Uncomment if not already set

$tagEnvironment = @{ Key = "Environment"; Value = "Lansa-Prod" }

# 1. Create VPC
$vpcCidr = "172.30.0.0/16"  # ← Replace with your original VPC CIDR if known
$vpc = New-EC2Vpc -CidrBlock $vpcCidr

New-EC2Tag -Resource $vpc.VpcId -Tag $tagEnvironment
New-EC2Tag -Resource $vpc.VpcId -Tag @{ Key = "Name"; Value = "AzureDevOps-VPC-us-east-1" }

Write-Host "Created VPC: $($vpc.VpcId)"

# 2. Create Internet Gateway (required if subnets need public access)
$igw = New-EC2InternetGateway
Add-EC2InternetGateway -InternetGatewayId $igw.InternetGatewayId -VpcId $vpc.VpcId
New-EC2Tag -Resource $igw.InternetGatewayId -Tag $tagEnvironment
New-EC2Tag -Resource $igw.InternetGatewayId -Tag @{ Key = "Name"; Value = "AzureDevOps-IGW-us-east-1" }

# 3. Create subnets (adjust CIDRs and AZs to match your original configuration)
$subnetsConfig = @(
    @{ Cidr = "172.30.0.0/20"; AZ = "us-east-1a"; Name = "AzureDevOps-Subnet-Public-1a" }
    @{ Cidr = "172.30.16.0/20"; AZ = "us-east-1b"; Name = "AzureDevOps-Subnet-Public-1b" }
    @{ Cidr = "172.30.32.0/20"; AZ = "us-east-1c"; Name = "AzureDevOps-Subnet-Public-1c" }
    # Add more subnets as needed, e.g., private subnets
)

$subnetIds = @()
foreach ($cfg in $subnetsConfig) {
    $subnet = New-EC2Subnet -VpcId $vpc.VpcId -CidrBlock $cfg.Cidr -AvailabilityZone $cfg.AZ
    Edit-EC2SubnetAttribute -SubnetId $subnet.SubnetId -MapPublicIpOnLaunch $true
    New-EC2Tag -Resource $subnet.SubnetId -Tag $tagEnvironment
    New-EC2Tag -Resource $subnet.SubnetId -Tag @{ Key = "Name"; Value = $cfg.Name }
    $subnetIds += $subnet.SubnetId
    Write-Host "Created subnet $($cfg.Name): $($subnet.SubnetId)"
}

# 4. Create Route Table and route to IGW (for public subnets)
$routeTable = New-EC2RouteTable -VpcId $vpc.VpcId
New-EC2Tag -Resource $routeTable.RouteTableId -Tag $tagEnvironment
New-EC2Tag -Resource $routeTable.RouteTableId -Tag @{ Key = "Name"; Value = "AzureDevOps-Public-RT" }

New-EC2Route -RouteTableId $routeTable.RouteTableId -DestinationCidrBlock "0.0.0.0/0" -GatewayId $igw.InternetGatewayId

# Associate public subnets with the route table
foreach ($subnetId in $subnetIds) {
    Register-EC2RouteTable -RouteTableId $routeTable.RouteTableId -SubnetId $subnetId
}

# 5. Create DB Subnet Group (if required for RDS)
$dbSubnetGroupName = "azuredevops-db-subnet-group-us-east-1"  # ← match your original name
$DBSubnetGroup = New-RDSDBSubnetGroup -DBSubnetGroupName $dbSubnetGroupName `
                     -DBSubnetGroupDescription "AzureDevOps DB Subnet Group us-east-1" `
                     -SubnetId $subnetIds
$DBSubnetGroup

Add-RDSTagsToResource -ResourceName $DBSubnetGroup.DBSubnetGroupArn -Tag $tagEnvironment

Write-Host "Re-creation complete."
Write-Host "New VPC ID: $($vpc.VpcId)"
Write-Host "New Subnet IDs: $($subnetIds -join ', ')"
Write-Host "New DB Subnet Group: $dbSubnetGroupName"
Write-Host "New Route Table: $($routeTable.RouteTableId)"
Write-Host "New Internet Gateway: $($igw.InternetGatewayId)"

# Important next steps:
# 1. Update your Azure DevOps variable group "VPC us-east-1" with the new IDs
#    - CurrentVPCUS        → $vpc.VpcId
#    - ELBSubnetIdsUS      → $subnetIds (comma-separated)
#    - DBSubnetGroupNameUS → $dbSubnetGroupName
# 2. Re-run the pipeline to test the new VPC/subnets