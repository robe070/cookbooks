#Requires -Version 3.0
#Requires -Module Az.Resources
#Requires -Module Az.Storage

Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('MYSQL', 'MSSQLS')]
    [String] $dbType
)

Enable-AzureRmAlias

Set-StrictMode -Version 3

$resourceGroupName = ""
$location = "Australia East"
$dirPath = "..\..\azure-quickstart-templates\lansa-vmss-windows-autoscale-sql-database\DatabaseDeploymentTemplates\"
$templateFilePath = ""
$templateParameterFilePath = ""

if ($dbType -eq 'MYSQL') {
    $templateFilePath = $dirPath + "mysqlTemplate.json"
    $templateParameterFilePath = $dirPath + "mysqlParameters.json"
    $resourceGroupName = "mysql1Test"
} else {
    $templateFilePath = $dirPath + "sqlServerTemplate.json"
    $templateParameterFilePath = $dirPath + "sqlServerParameters.json"
    $resourceGroupName = "mssql1Test"
}

New-AzResourceGroup -Name $resourceGroupName -Location $location -Verbose -Force -ErrorAction Stop
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
    -TemplateFile $templateFilePath `
    -TemplateParameterFile $templateParameterFilePath `
    -Force -Verbose `
    -ErrorVariable ErrorMessages
