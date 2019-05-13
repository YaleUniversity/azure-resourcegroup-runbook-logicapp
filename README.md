# Creation of Azure Resource Groups through Serverless Automation

## Introduction
A resource group in Azure is a container that holds Azure resources such as virtual machine instances, virtual networks, storage accounts, etc. It provides an accounting and security context for the life cycle of resources within its scope. Access to the resources within the boundaries of this scope is granted to security principals (which take the form of users or applications) in Azure Active Directory. The degree of access is determined by the policies attached to the roles assigned to these security principals. 

Because resource groups comprise assets that should be managed together, they offer a convenient way to align the functionality provided by those resources to the costs that they incur.

As an example, a resource group could contain the databases for an application in the productio environment. One could limit full access to these databases by assigning the `Owner` role to the users in the group of enterprise database administrators over the resource group. Furthermore, the total cost for running the databases for the applications in the production environment is reflected by the costs of the individual databases inside the resource group.

Given its importance, a case can be made for an automated process that wraps sufficient business rules to enforce conformance in their creation.

## Description of Solution

This proposed solution adheres to the following design principles:

1. Cloud automation should proceed bottom up. This automation should be derived from well understood and documented pipelines of business events. It should originate directly from the automation artifacts of the teams responsible for the creation and maintenance of resources in the cloud.
2. Cloud automation should be reusable. This reusability should be accomplished by taking advantage of cloud native platform services to create an institutional API clearinghouse.
3. Cloud automation should provide sufficient functionality to enable the performance of repetitive tasks against the cloud platform. Much of the benefit a public cloud obtains from its providing capability complementary to the an institution's investments in compute and infrastructure. Cloud automation should not wrap the access to the full capabilities of the platform. (Rather, it is the purpose of governance, design, security, identity, and financial controls to provide the structure for direct access to the features of the public cloud.)

For several months, the operational infrastructure administrators have been creating and tagging resource groups through direct access of the Azure portal as well as the Powershell `Az` commandlets. The financial administrator for Azure resources has been monitoring and controlling costs by requiring that resources adhere to a specific naming convention and possess tags denoting the contact email of the owner, an institutional charging account identifier, application name, and the deployment environment. The information security oprations team requires that resources in Azure be identified with a data risk designation aligned to their security policies. This designation will be used to audit and monitor and control access.

The institution has been adopting DevOps approaches and patterns of behavior. The operations engineering team has observed coalescence around a set of well-defined inputs, processes, and outputs governed by business rules around the naming conventions and tagging of these resource groups.

They have refactored the Azure Resource Group templates and have begun to create a library of Powershell code snippets to reliably create appropriately named and tagged resource groups.

The operational team has has been maintaining and storing this library in a common repository. They invoke the code interactively to create resource groups that conform to naming and resource tagging conventions.

However, another team has created a self-service portal that allows members of the institution to create resources in multiple public and private clouds through REST API calls against cloud platform endpoints. This team would like to bring Azure within the portfolio of services available through their tool. They would like to leverage the operational team's Azure automation library.

Azure provides many options to facilitate the reusability of automation.  [TODO: Discuss serverless and event driven implementations in Azure.] This solution takes advantage of Azure Blob Storage to store Azure Resource Manager templates, Azure Automation Runbooks to host the PowerShell automation, and Logic Apps to provide a lightweight API endpoint to trigger the Runbook and return an HTTP response with the results of the action.

![ResourceGroupLogicAppArchitecture](assets/ResourceGroupLogicAppArchitecture.svg)

## Implementation of Solution

### Manually Create an Azure Resource Group

Although this solution is intended to create resource groups within a subscription, one must create an initial resource group to contain the components of the solution.

A resource group template that enforces business rules around naming and tagging will be used to create this resource group.

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#",
    "contentVersion": "1.0.0.1",
    "metadata": {
        "comment": "This Azure Resource Managemer template creates an Azure Resource Group. It enforces conventions regarding the resource name and its tags.",
        "author": "Yale University",
        "licence": {
            "uri": "/LICENSE.md"
        }
    },
    "parameters": {
        "ResourceLocation": {
            "type": "string",
            "metadata": {
                "Description": "Azure region. (NB, This value will override the `-Location` parameter specified by `New-AzDeployment` or  the `--location` option of `az deploy create`"
            }
        },
        "OwnerSignInName": {
            "type": "string",
            "metadata": {
                "description": "The Azure sign-in name (email address) of the functional owner of the resource group to be placed into Azure. The person to be notified of changes or interruptions to the operations of their application or workload in Azure.",
                "comment": "Institutional Property"
            }
        },
        "ChargingAccount": {
            "type": "string",
            "metadata": {
                "description": "The string denoting the account to which costs incurred by the application or workload to be placed in Azure should be charged.",
                "comment": "Institutional Property"
            }
        },
        "ApplicationName": {
            "type": "string",
            "metadata": {
                "description": "A string that identifies the product or function of the application or workload to be placed into Azure.",
                "comment": "Institutional Property"
            }
        },
        "ApplicationBusinessUnit": {
            "type": "string",
            "metadata": {
                "description": "A string that identifies the institutional business unit or academic department served by he product or function of the application to be placed into Azure",
                "comment": "Institutional Property"
            }            
        },
        "Environment": {
            "type": "string",
            "allowedValues": [ "dev", "test", "prod", "Dev", "Test", "Prod" ],
            "metadata": {
                "description": "The application or workload environment. Available values are dev, test and prod.",
                "comment": "Institutional Property"
            }
        },
        "DataSensitivity": {
            "type": "string",
            "defaultValue": "none",
            "allowedValues": [ "High", "Moderate", "Low", "None", "high", "moderate", "low", "none" ],
            "metadata": {
                "description": "A string that denotes the degree of risk and impact to the institution should data handled by the resource be disclosed outside of the institution [ref](https://cybersecurity.yale.edu/classifyingtechnology).",
                "comment": "Institutional Property"
            }
        }
    },
    "variables": {
        "resourceGroupName": "[concat(parameters('ApplicationName'), '-', parameters('ApplicationBusinessUnit'), '-', parameters('Environment'), '-', parameters('ResourceLocation'), '-rg')]",
        "resourceLocation": "[parameters('ResourceLocation')]",
        "resourceTags": {
            "Application": "[concat(parameters('ApplicationName'), '-', parameters('ApplicationBusinessUnit'))]",
            "OwnerDepartmentContact": "[parameters('OwnerSignInName')]",
            "DataSensitivity": "[parameters('DataSensitivity')]",
            "ChargingAccount": "[parameters('ChargingAccount')]",
            "Name": "[variables('resourceGroupName')]"
        }
    },
    "resources": [
        {
            "type": "Microsoft.Resources/resourceGroups",
            "apiVersion": "2018-05-01",
            "location": "[variables('resourceLocation')]",
            "name": "[variables('resourceGroupName')]",
            "tags": "[variables('resourceTags')]",
            "properties": {}
        }
    ],
    "outputs": {
        "resourceGroupName": {
            "type": "string",
            "value": "[variables('resourceGroupName')]"
        },
        "resourceId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Resources/resourceGroups', variables('resourceGroupName'))]"
        },
        "tags": {
            "type": "object",
            "value": "[variables('resourceTags')]"
        }
    }
}
```

This template will be used by the automated process to create subsequent resource groups.

(This template is based on the raw json template exports of resources created by routine operations. Common values in those templates were refactored into reusable variables in the `"variables"` node of the template. Common input values to create this resource have been refactored into the `"parameters"` node and constitute a lightweight interface for deployment. The details for this iterative approach to Azure Resource Manager template authoring will be covered in a subsequent document.)

```powershell

# Replace all strings enclosed by `{{` and `}}` with specific values

Login-AzLogin -Subscription '{{ SUBSCRIPTION_NAME }}'

$AZURE_SUBSCRIPTION_ID = $(Get-AzContext).Subscription.Id
$AZURE_DEPLOYMENT = "resourcegroup-$(Get-Date -Format 'yyMMddHHmmm')-deployment"
$AZURE_DEPLOYMENT_LOCATION = '{{ DeploymentLocation }}'

$AZURE_DEPLOYMENT_PARAMETERS = @{}

  $AZURE_DEPLOYMENT_PARAMETERS = @{
    ResourceLocation         = '{{ ResourceLocation }}'
    OwnerSignInName          = '{{ OwnerSignInName }}'
    ChargingAccount          = '{{ ChargingAccount }}'
    ApplicationName          = '{{ ApplicationName }}'
    ApplicationBusinessUnit  = '{{ ApplicationBusinessUnit }}'
    Environment              = '{{ Environment }}'
    DataSensitivity          = '{{ DataSensitivity }}'
}


$deployment = New-AzDeployment -Name $AZURE_DEPLOYMENT `
                               -Location $AZURE_DEPLOYMENT_LOCATION `
                               -TemplateFile ./templates/resourcegroup/azuredeploy.json `
                               -TemplateParameterObject $AZURE_DEPLOYMENT_PARAMETERS

$AZURE_RESOURCE_GROUP = $deployment.Outputs.resourceGroupName.Value


```

### Create Storage Account and Upload ARM Template Artifacts to Blob Storage

An Azure Storage Account will be created to serve as an artifact repository for the Azure Resource Manager templates released by the developer/operator teams.

(Note, we will upload the resource group ARM template directly into the Azure Storage blob container. One can extend this solution by incorporating an Azure Devops Pipeline that outputs the resource group ARM template into this container.)

```powershell
# Create a storage account to park artifacts used by the Automation account
# Add deployment parameters to existing hashtable specific to Storage

$AZURE_STORAGE_ACCOUNT_DEPLOYMENT_PARAMETERS =  $AZURE_DEPLOYMENT_PARAMETERS + @{
    SkuName           = 'Standard_LRS'
    AccountKind       = 'StorageV2'
    AccessTierDefault = 'Hot'
    CustomDomain      = ''
}

$AZURE_DEPLOYMENT = "storageaccount-$(Get-Date -Format 'yyMMddHHmmm')-deployment"

$deploymentStorageAccount = New-AzResourceGroupDeployment -Name $AZURE_DEPLOYMENT `
                                                          -ResourceGroupName $AZURE_RESOURCE_GROUP `
                                                          -TemplateFile ./templates/storageaccount/azuredeploy.json `
                                                          -TemplateParameterObject $AZURE_STORAGE_ACCOUNT_DEPLOYMENT_PARAMETERS

$AZURE_STORAGE_ACCOUNT = $deploymentStorageAccount.Outputs.storageAccountName.Value
$AZURE_STORAGE_KEY = $(Get-AzStorageAccountKey -Name "$AZURE_STORAGE_ACCOUNT" -ResourceGroupName "$AZURE_RESOURCE_GROUP" | ? {$_.KeyName -eq 'key1'}).Value


$AZURE_STORAGE_CONTEXT = New-AzStorageContext -StorageAccountName "$AZURE_STORAGE_ACCOUNT" `
                        -StorageAccountKey "$AZURE_STORAGE_KEY"

# Create containers to hold template and PS module artifacts
New-AzStorageContainer -Context $AZURE_STORAGE_CONTEXT -Name 'templates'

# Upload template files
Get-ChildItem -Recurse ./templates -Filter '*.json' | % {Set-AzStorageBlobContent -File $_ -Context $AZURE_STORAGE_CONTEXT -Container 'templates' -Blob $($_.Directory.Name + '/' + $_.Name) -Properties @{"ContentType" = "application/json"} }

```

### Create Azure Automation Account

An Azure Automation Account is a container that holds the assets necessary to perform automation tasks against Azure resources, as well as external resources. The Azure automation account comprises common assets such scripts and workflows, modules, and variables. It can accommodate Python2 and PoweShell, two high-level interpreted languages commonly used by system administrators for routine automation tasks. 

```powershell
# Create Automation Account
$automationAccount = New-AzAutomationAccount -Name 'resourcegroup-automation' `
                                             -ResourceGroupName $AZURE_RESOURCE_GROUP `
                                             -Location $AZURE_DEPLOYMENT_LOCATION `
                                             -Plan basic

$AZURE_AUTOMATION_ACCOUNT_NAME = $automationAccount.AutomationAccountName
$AZURE_AUTOMATION_ACCOUNT_APPID = $(Get-AzADApplication -DisplayNameStartWith $('{0}_' -f $AZURE_AUTOMATION_ACCOUNT_NAME)).ApplicationId.Guid

```

An automation account contains an Azure Runas Account, an application service principal that is granted a `Contributor` role to the subscription.

Additionally, this runas account will require the `Owner` role assigned to it at the `resourcegroups` scope of the subscription since it will need to assign ownership of the resource group to the user.

In the Azure Portal, creating an Azure Automation Account creates an Azure Runas Account. (Actually, it creates two accounts--each corresponding to Azure Resource Manager and Azure Classic.)

Microsoft provides a convenient script [New-RunasAccount.ps1](https://docs.microsoft.com/en-us/azure/automation/manage-runas-account) that creates a new self-signed certificate, creates an application service principal associated witht he automatin account, creates an automation connection, and assignes the `Contributor` role to the service principal over a specified subscription.

Because this script assumes a Windows server environment, it will not work with PowerShell Core (Dotnet Core). It will be necessary to use the Azure Portal.

(**TODO**: Incorporate [SelfSignedCertificate](https://www.powershellgallery.com/packages/SelfSignedCertificate/0.0.4) module for pure CLI implementation.)

Navigate to the Azure Portal page for the automation account **resourcegroup-automation** and select **Run as accounts** under **Account Settings**. Click on **Azure Run as Account**.

![CreateAzureAutomationRunasAccountBladeAzurePortal](assets/CreateAzureAutomationRunasAccountBladeAzurePortal.png)

Click **Create** on the following blade:

![CreateAzureAutomationRunasRMAzurePortal](assets/CreateAzureAutomationRunasRMAzurePortal.png)

This will result in a new **Azure Automation Run As Account**:

![AzureAutomationRunasAccountBladeAzurePortal](assets/AzureAutomationRunasAccountBladeAzurePortal.png)

A corresponding **AzureRunAsConnection** will be created also and can be viewed under the **Shared Resources** of the ***resourcegroups-automation** Azure Automation Account:

![SharedResourcesAzureAutomationBladeAzurePortal](assets/SharedResourcesAzureAutomationBladeAzurePortal.png)

To enable Runbook automation to perform operations against resources in the subscription, Azure assigns the `Contributor` role to the **Azure Run As Account** over the scope of hte subscription. In the particular case of this runbook script, the **Azure Run As Account** will require additional privileges. It requires the assignment the `Owner` role over the subscription because it must have the power to assign `Contributor` or `Owner` role to the user account corresponding to the User Principal Name (Sign In Name) specified in the JSON request to the Logic App trigger.


```powershell
# Assign the owner role for the RunAsAccount over the Subscription scope
New-AzRoleAssignment -ApplicationId $AZURE_AUTOMATION_ACCOUNT_APPID `
                     -RoleDefinitionName 'Owner' `
                     -Scope $('/subscriptions/{0}' -f $AZURE_SUBSCRIPTION_ID)
```

Second, the **Azure Run As Account** requires sufficient privileges against the Azure AD Graph API  to read the Azure User object's properties. An Azure Active Directory administrator must assign `directory.read.all` role to the service principal in **App Registration** blade of the **Azure Portal**.

```powershell
# Establish variables for the runbook to use
New-AzAutomationVariable -AutomationAccountName $AZURE_AUTOMATION_ACCOUNT_NAME `
                         -ResourceGroupName $AZURE_RESOURCE_GROUP `
                         -Encrypted $False `
                         -Name 'AZURE_STORAGE_ACCOUNT' `
                         -Value $AZURE_STORAGE_ACCOUNT

New-AzAutomationVariable -AutomationAccountName $AZURE_AUTOMATION_ACCOUNT_NAME `
                         -ResourceGroupName $AZURE_RESOURCE_GROUP `
                         -Encrypted $True `
                         -Name 'AZURE_STORAGE_KEY' `
                         -Value $AZURE_STORAGE_KEY

New-AzAutomationVariable -AutomationAccountName $AZURE_AUTOMATION_ACCOUNT_NAME `
                         -ResourceGroupName $AZURE_RESOURCE_GROUP `
                         -Encrypted $False `
                         -Name 'AZURE_STORAGE_ACCOUNT_RESOURCEGROUP' `
                         -Value $AZURE_RESOURCE_GROUP

New-AzAutomationVariable -AutomationAccountName $AZURE_AUTOMATION_ACCOUNT_NAME `
                         -ResourceGroupName $AZURE_RESOURCE_GROUP `
                         -Encrypted $False `
                         -Name 'AZURE_STORAGE_CONTAINER' `
                         -Value 'templates'

New-AzAutomationVariable -AutomationAccountName $AZURE_AUTOMATION_ACCOUNT_NAME `
                         -ResourceGroupName $AZURE_RESOURCE_GROUP `
                         -Encrypted $False `
                         -Name 'AZURE_TEMPLATE_BLOB' `
                         -Value 'resourcegroup/azuredeploy.json'

# Add Necessary Az modules

$AZURE_AUTOMATION_MODULES = @(
    'Az.Accounts',
    'Az.Resources',
    'Az.Storage'
) | % {Find-Module -Name $_ -Repository PSGallery}


# TODO: Aa.Accounts must be imported successfully first; otherwise subsequet Az.* module imports fail.
# Create polling loop before importing Az.Resources and Az.Storage.

$AZURE_AUTOMATION_MODULES | % {
    New-AzAutomationModule -AutomationAccountName $AZURE_AUTOMATION_ACCOUNT_NAME `
                           -ResourceGroupName $AZURE_RESOURCE_GROUP `
                           -ContentLink $('{0}/package/{1}/{2}' -f $_.RepositorySourceLocation, $_.Name, $_.Version) `
                           -Name $_.Name
}

Import-AzAutomationRunbook -Path .\runbook\New-ResourceGroup.ps1 `
                           -ResourceGroupName $AZURE_RESOURCE_GROUP `
                           -AutomationAccountName $AZURE_AUTOMATION_ACCOUNT_NAME `
                           -Type PowerShell

```

In order for the automation account to access the storage blob, the `Azure Storage Blob Reader` role must be assigned to it. Returning to PowerShell:

```powershell

$AZURE_AUTOMATION_ACCOUNT_APPID = $(Get-AzADApplication -DisplayNameStartWith $('{0}_' -f $AZURE_AUTOMATION_ACCOUNT_NAME)).ApplicationId.Guid
$AZURE_STORAGE_ROLE_SCOPE = $('/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Storage/storageAccounts/{2}/blobServices/default/containers/{3}' -f $AZURE_SUBSCRIPTION_ID, $AZURE_RESOURCE_GROUP, $AZURE_STORAGE_ACCOUNT, 'templates')

New-AzRoleAssignment -ApplicationId $AZURE_AUTOMATION_ACCOUNT_APPID `
    -RoleDefinitionName "Storage Blob Data Reader" `
    -Scope  "$AZURE_STORAGE_ROLE_SCOPE"
```

## Create Azure Logic App, HTTP Trigger

An Azure Runbook allows an operations team to reuse automation code. It provides a container and runtime environment for the code. By exposing parameters of a Python 2 or Powershell script,it provides a convenient, lightweight user interface for operational tasks.

Azure Logic Apps enables the creation of automation workflows that can integrate data, events, conditions, and applications within Azure Azure, private clouds, and other public cloud platforms.

In this solution, a simple workflow is triggered by an HTTP request that is carrying a JSON payload of data collected by a self-service web application. The payload contains a user id, , department, contact email, charging code, environment, data security sensitivty level, and application name. The Logic App workflow de-serializes the JSON payload and furnishes them as inputs to Azure runbook. When the Azure Runbook completes, Logic Apps returns an HTTP response with the results of the runbook action serialized as JSON.

## Test Solution
```bash
curl "$AZURE_LOGICAPP_HTTP_ENDPOINT"-H 'Content-Type: application/json' -d "${JSON_PAYLOAD}"`
```

```powershell
Invoke-WebRequest -Uri
```

## Author

Vincent Balbarin <vincent.balbarin@yale.edu>

## License

The licenses of these documents are held by [@YaleUniversity](https://github.com/YaleUniversity)under the [MIT License](/LICENSE.md).

## References
[5 Approaches for Public Cloud Self-Service Enablement and Governance (Gartner Subscriber Content)](https://www.gartner.com/document/3880094)

[Resource Group Template Deploy](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-deploy)

[Manage Runas Account](https://docs.microsoft.com/en-us/azure/automation/manage-runas-account)

[Automation Deploy Template Runbook](https://docs.microsoft.com/en-us/azure/automation/automation-deploy-template-runbook) 