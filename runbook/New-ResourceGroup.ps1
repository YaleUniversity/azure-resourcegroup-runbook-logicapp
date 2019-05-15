[CmdletBinding()]

param(
    [Parameter(Mandatory=$True,HelpMessage='Azure Region to which this resource will be deployed.')]
    [string] $ResourceLocation,

    [Parameter(Mandatory=$True,HelpMessage='The Azure sign-in name (email address) of the functional owner of the resource group to be placed into Azure. The person to be notified of changes or interruptions to the operations of their application or workload in Azure.')]
    [string] $OwnerSignInName,

    [Parameter(Mandatory=$True,HelpMessage='The string denoting the account to which costs incurred by the application or workload to be placed in Azure should be charged.')]
    [string] $ChargingAccount,

    [Parameter(Mandatory=$True,HelpMessage='A string that identifies the product or function of the application or workload to be placed into Azure.')]
    [string] $ApplicationName,
    
    [Parameter(Mandatory=$True,HelpMessage='A string that identifies the institutional business unit or academic department served by he product or function of the application to be placed into Azure.')]
    [string] $ApplicationBusinessUnit,

    [Parameter(Mandatory=$True,HelpMessage='The application or workload environment. Available values are dev, test and prod.')]
    [ValidateSet('dev', 'test', 'prod', 'Dev', 'Test', 'Prod')]
    [string] $Environment,

    [Parameter(Mandatory=$True,HelpMessage='A string that denotes the degree of risk and impact to the institution should data handled by the resource be disclosed outside of the institution [ref](https://cybersecurity.yale.edu/classifyingtechnology).')]
    [ValidateSet('High', 'Moderate', 'Low', 'None', 'high', 'moderate', 'low', 'none')]
    [string] $DataSensitivity

)

$DEPLOYMENT_PARAMETERS = @{}
$DEPLOYMENT_PARAMETERS = @{
    ResourceLocation        = $ResourceLocation
    OwnerSignInName         = $OwnerSignInName
    ChargingAccount         = $ChargingAccount
    DataSensitivity         = $DataSensitivity
    Environment             = $Environment
    ApplicationName         = $ApplicationName
    ApplicationBusinessUnit = $ApplicationBusinessUnit
}

$TEMP = $(New-TemporaryFile).DirectoryName
$AZURE_STORAGE_ACCOUNT = Get-AutomationVariable -Name 'AZURE_STORAGE_ACCOUNT'
$AZURE_STORAGE_KEY = Get-AutomationVariable -Name 'AZURE_STORAGE_KEY'
$AZURE_STORAGE_ACCOUNT_RESOURCEGROUP = Get-AutomationVariable -NAME 'AZURE_STORAGE_ACCOUNT_RESOURCEGROUP'
$AZURE_STORAGE_CONTAINER = Get-AutomationVariable -NAME 'AZURE_STORAGE_CONTAINER'
$AZURE_TEMPLATE_BLOB = Get-AutomationVariable -NAME 'AZURE_TEMPLATE_BLOB'

$connectionName = "AzureRunAsConnection"

$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

# Connect to Azure AD and obtain an authorized context to access directory information regarding owner
# and (in the future) access a blob storage container without a SAS token or storage account key

Add-AzAccount -ServicePrincipal `
              -TenantId $servicePrincipalConnection.TenantId `
              -ApplicationId $servicePrincipalConnection.ApplicationId `
              -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint

$userObjectId = $(Get-AzAdUser -UPN $DEPLOYMENT_PARAMETERS.OwnerSignInName).Id

<#
# This obtains a storage context based on the AZ credentials of Azure Runas Account
# AAD access of Storage Blob Containers is in preview mode.
# Allowing AAD access of Storage Blob Containers can only be set in the portal and
# `az-cli`. Powershell and ARM templates does not support this setting yet.

$storageContext = New-AzStorageContext -StorageAccountName "$AZURE_STORAGE_ACCOUNT" `
                                       -UseConnectedAccount
#>

# Obtain storage context

$storageContext = New-AzStorageContext -StorageAccountName "$AZURE_STORAGE_ACCOUNT" `
                                       -StorageAccountKey "$AZURE_STORAGE_KEY"

$blob = Get-AzStorageBlobContent -Context $storageContext `
                         -Container "$AZURE_STORAGE_CONTAINER" `
                         -Blob "$AZURE_TEMPLATE_BLOB" `
                         -Destination "$TEMP" `
                         -Force

$azuredeployTemplate = Get-Content -Path "$(Join-Path $TEMP $AZURE_TEMPLATE_BLOB)" -Encoding UTF8

$deploymentName = "$OwnerNetId-$(Get-Date -Format 'yyMMddHHmmm')-deployment"
$deployment = New-AzDeployment -Name $deploymentName `
                               -Location $ResourceLocation `
                               -TemplateFile "$(Join-Path $TEMP $AZURE_TEMPLATE_BLOB)" `
                               -TemplateParameterObject $DEPLOYMENT_PARAMETERS

$deployment

$DEPLOYMENT_PARAMETERS.OwnerSignInName

New-AzRoleAssignment -SignInName $DEPLOYMENT_PARAMETERS.OwnerSignInName `
                     -ResourceGroupName $deployment.Outputs.resourceGroupName.Value `
                     -RoleDefinitionName 'Contributor'