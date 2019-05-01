[CmdletBinding()]

param(
    [Parameter(Mandatory=$True,HelpMessage='Azure Region to which this resource will be deployed.')]
    [string] $ResourceLocation,

    [Parameter(Mandatory=$True,HelpMessage='The network id of the functional owner of the application or workload to be placed in Azure.')]
    [string] $OwnerNetId,

    [Parameter(Mandatory=$True,HelpMessage='The abbreviation for the department of the functional owner of the application or workload to be placed in Azure.')]
    [string] $OwnerDepartment,

    [Parameter(Mandatory=$True,HelpMessage='The email address of the functional owner of the application or workload to be placed in Azure. The person to be notified of changes or interruptions to the operations of their application or workload in Azure.')]
    [string] $OwnerDepartmentContact,

    [Parameter(Mandatory=$True,HelpMessage='The string denoting the account to which costs incurred by the application or workload to be placed in Azure should be charged.')]
    [string] $ChargingAccount,

    [Parameter(Mandatory=$True,HelpMessage='A string that denotes the degree of risk and impact to the institution should data handled by the resource be disclosed outside of the institution [ref](https://cybersecurity.yale.edu/classifyingtechnology).')]
    [ValidateSet('High', 'Moderate', 'Low', 'None', 'high', 'moderate', 'low', 'none')]
    [string] $DataSensitivity,

    [Parameter(Mandatory=$True,HelpMessage='The application or workload environment. Available values are dev, test and prod.')]
    [ValidateSet('dev', 'test', 'prod', 'Dev', 'Test', 'Prod')]
    [string] $Environment,

    [Parameter(Mandatory=$True,HelpMessage='A string that identifies the product or function of the application or workload to be placed in Azure.')]
    [string] $Application
)

$DEPLOYMENT_PARAMETERS = @{}
$DEPLOYMENT_PARAMETERS = @{
    ResourceLocation         = $ResourceLocation
    OwnerNetId               = $OwnerNetId
    OwnerDepartment          = $OwnerDepartment
    OwnerDepartmentContact   = $OwnerDepartmentContact
    ChargingAccount          = $ChargingAccount
    DataSensitivity          = $DataSensitivity
    Environment              = $Environment
    Application              = $Application
}

$TEMP = $(New-TemporaryFile).DirectoryName
$AZURE_STORAGE_ACCOUNT = Get-AutomationVariable -Name 'AZURE_STORAGE_ACCOUNT'
$AZURE_STORAGE_ACCOUNT_RESOURCEGROUP = Get-AutomationVariable -NAME 'AZURE_STORAGE_ACCOUNT_RESOURCEGROUP'
$AZURE_STORAGE_CONTAINER = Get-AutomationVariable -NAME 'AZURE_STORAGE_CONTAINER'
$AZURE_TEMPLATE_BLOB = Get-AutomationVariable -NAME 'AZURE_TEMPLATE_BLOB'

$connectionName = "AzureRunAsConnection"

$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

Add-AzAccount -ServicePrincipal `
              -TenantId $servicePrincipalConnection.TenantId `
              -ApplicationId $servicePrincipalConnection.ApplicationId `
              -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint

# Storage Blob Container should be configured to use AAD authentication (preview)
$storageContext = New-AzStorageContext -StorageAccountName "$AZURE_STORAGE_ACCOUNT" `
                                       -UseConnectedAccount

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
                               -TemplateParameterObject $DEPLOYMENT_PARAMETERS `
                               -WhatIf
$deployment

# Return Context of user account
Get-AzContext

<#
TODO: Assign the Owner or Contributor to the newly created resource group.

**HOWEVER**, the RunasAutomationAccount cannot read AAD to retreieve the ADUser associated
with the provided email/SignOnName.

As a test,
Get-AzADUser -UPN first.last@{{ domain name}} returns nothing.
#>