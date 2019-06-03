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

$AZUREDEPLOY_PARAMETERS = @{}
$AZUREDEPLOY_PARAMETERS = @{
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

try
{
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

    # Connect to Azure AD and obtain an authorized context to access directory information regarding owner
    # and (in the future) access a blob storage container without a SAS token or storage account key

    Add-AzAccount -ServicePrincipal `
                  -TenantId $servicePrincipalConnection.TenantId `
                  -ApplicationId $servicePrincipalConnection.ApplicationId `
                  -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 3>&1 2>&1 > $null
}
catch
{
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } 
    else
    {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Obtain storage context

($AZURE_STORAGE_CONTEXT = New-AzStorageContext -StorageAccountName "$AZURE_STORAGE_ACCOUNT" `
                                              -StorageAccountKey "$AZURE_STORAGE_KEY") 3>&1 2>&1 > $null

(Get-AzStorageBlobContent -Context $AZURE_STORAGE_CONTEXT `
                         -Container "$AZURE_STORAGE_CONTAINER" `
                         -Blob "$AZURE_TEMPLATE_BLOB" `
                         -Destination "$TEMP" `
                         -Force) 3>&1 2>&1 > $null

<#
TODO: Use AAD to create storage context. This feature is preview currently (2019-05-22). See commit (ad900b1) message for notes.
#>

$AZURE_DEPLOYMENT_NAME = "$OwnerNetId-$(Get-Date -Format 'yyMMddHHmmm')-deployment"
($AZURE_DEPLOYMENT = New-AzDeployment -Name $AZURE_DEPLOYMENT_NAME `
                                      -Location $AZUREDEPLOY_PARAMETERS.ResourceLocation `
                                      -TemplateFile "$(Join-Path $TEMP $AZURE_TEMPLATE_BLOB)" `
                                      -TemplateParameterObject $AZUREDEPLOY_PARAMETERS) 3>&1 2>&1 > $null

$resourceGroupName = ($AZURE_DEPLOYMENT.outputs.resourceId.value).Split('/')[-1]
$resourceGroupTags = (Get-AzResourceGroup -Name $resourceGroupName).Tags

($AZURE_ROLEASSIGNMENT = New-AzRoleAssignment -SignInName $AZUREDEPLOY_PARAMETERS.OwnerSignInName `
                                              -ResourceGroupName $AZURE_DEPLOYMENT.Outputs.resourceGroupName.Value `
                                              -RoleDefinitionName 'Contributor') 3>&1 2>&1 > $null

$AZURE_RUNBOOK_OUTPUT = @{}

$AZURE_RUNBOOK_OUTPUT = [PSCustomObject] @{
    ResourceGroupName = $resourceGroupName
    ResourceId = $AZURE_DEPLOYMENT.outputs.resourceId.value
    Tags = $resourceGroupTags
    RoleAssignment = @{
        User = $AZURE_ROLEASSIGNMENT.DisplayName
        Role = $AZURE_ROLEASSIGNMENT.RoleDefinitionName
    }
}

Write-Output ( $AZURE_RUNBOOK_OUTPUT | ConvertTo-Json )