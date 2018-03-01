# Azure Managed Application

Azure Managed Applications enable you to offer your Moodle based
solutions to internal and external customers. You define the
infrastructure for the solution, using the ARM templates in this
repository as a starting point, along with the terms for ongoing
management of the solution. The billing for your solution is handled
through Azure billing.

## Why Managed Applications?

Managed applications reduce barriers to consumers using your
solutions. They do not need expertise in cloud infrastructure to use
your solution. Consumers have limited access to the critical
resources. They do not need to worry about making a mistake when
managing it.

Managed applications enable you to establish an ongoing relationship
with your consumers. You define terms for managing the application,
and all charges are handled through Azure billing.

Although customers deploy these managed applications in their
subscriptions, they don't have to maintain, update, or service them.
That is something you provide as a service to the customer. You can
ensure that all customers are using approved versions. Customers don't
have to develop application-specific domain knowledge to manage these
applications. Customers automatically acquire application updates
without the need to worry about troubleshooting and diagnosing issues
with the applications.

For IT teams, managed applications enable you to offer pre-approved
solutions to users in the organization. You ensure these solutions are
compliant with organizational standards.

Read more about [Managed
Applications](https://docs.microsoft.com/en-us/azure/managed-applications/overview),
or keep reading here to see how to quickly get started providing your
own Moodle based services as Managed Applications.

## Prerequisites

In the following sections we demonstrate how to use the Azure CLI to
work with a Moodle based Managed Application. For convenience these
commands use a variety of [environment variables](Environment.md) that
should be configured first.

## Defining the Resources (mainTemplate.json)

The `mainTemplate.json` file defines the Azure resources that are
provisioned as part of the managed application. We've already done the
majority of the work here for you (see `azuredeploy.json` in the root
of this repository). The `mainTemplate.json` file is where you
customize the configuration and, optionally, add additional resources.

An initial `mainTemplate.json` file is provided in
`managedApplication/maintemplte.json`. This file is sufficient to get
you started building your own Moodle based Managed Applications.

This file is a regular [Azure Resource Manager template](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-overview).

## User Interface Definition (createUIDefinition.json)

The `createUIDefinition.json` file describes the user interface needed
to configure the managed application. It defines how the user provides
input for each of the parameters (specified in `mainTemplate.json`).

An initial `createUIDefinition.json` file is provided in
`managedApplication/creatueUIDefinition.json`. This files is
sufficient to get you started building your own Moodle based Managed
Applications.

See [Create UI Definition
documentation](https://docs.microsoft.com/en-us/azure/managed-applications/create-uidefinition-overview) for more information.

## Create an Azure Active Directory User Group or Application

You will need to create one ore more user group or appliction in Azure
Active Directory to allow you to manage the applications resources on
behalf of your customer. These groups or application can be given any
built-in Role-Based Access Control (RBAC) role, such as 'Owner' or
'Contributor'. By creating more than one such group or application you
can configure access to your customers resources based on the specific
needs of each role in your organization.

Azure has full documentation on [creating a group in Azure Active
Directory](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-groups-create-azure-portal). The commands below will create a single 'owner' role for
use in the examples below.

Create the group:

``` bash
az ad group create --display-name $MOODLE_MANAGED_APP_OWNER_GROUP_NAME --mail-nickname=$MOODLE_MANAGED_APP_OWNER_NICKNAME
```

Results:

``` json
{
  "additionalProperties": {
    "deletionTimestamp": null,
    "description": null,
    "dirSyncEnabled": null,
    "lastDirSyncTime": null,
    "mailEnabled": false,
    "mailNickname": "MoodleOwner",
    "odata.metadata": "https://graph.windows.net/72f988bf-86f1-41af-91ab-2d7cd011db47/$metadata#directoryObjects/Microsoft.DirectoryServices.Group/@Element",
    "odata.type": "Microsoft.DirectoryServices.Group",
    "onPremisesDomainName": null,
    "onPremisesNetBiosName": null,
    "onPremisesSamAccountName": null,
    "onPremisesSecurityIdentifier": null,
    "provisioningErrors": [],
    "proxyAddresses": []
  },
  "displayName": "MoodleOwner",
  "mail": null,
  "objectId": "dd46cacd-eab1-43b0-a4ba-425d8b8d82fa",
  "objectType": "Group",
  "securityEnabled": true
}
```

You'll need the object ID from this output. For convenience we'll
create an environment variable set to the object ID value.

``` bash
MOODLE_MANAGED_APP_AD_ID=$(az ad group list --filter="displayName eq '$MOODLE_MANAGED_APP_OWNER_GROUP_NAME'" --query [*].objectId --output tsv)
```

You will also need the Role ID for your chosen role, here we will use
the built in 'Owner' role:

``` bash
MOODLE_MANAGED_APP_ROLE_ID=$(az role definition list --name Owner --query [].name --output tsv)
```

The Azure documentation has more information on how to work with [Azure Active Directory](https://docs.microsoft.com/en-us/azure/active-directory/manage-access-to-azure-resources).

## Create a Resource Group for the Managed Application Service Catalog Entry

``` bash
az group create --name $MOODLE_SERVICE_CATALOG_RG_NAME --location $MOODLE_SERVICE_CATALOG_LOCATION
```

## Deploy to your Service Catalog using Azure CLI

You can deploy a Managed Application into your Service Catalog using
the Azure CLI. For convenience we'll set a few environment variables
to make it easier to work with the application.We'll need to construct
the authorization configuration from the app and role IDs retrieved
earlier.

``` bash
MOODLE_MANAGED_APP_AUTHORIZATIONS=$MOODLE_MANAGED_APP_AD_ID:$MOODLE_MANAGED_APP_ROLE_ID
```

The following command will add your managed application to the Service Catalog.

``` bash
az managedapp definition create --name $MOODLE_MANAGED_APP_NAME --location $MOODLE_SERVICE_CATALOG_LOCATION --resource-group $MOODLE_SERVICE_CATALOG_RG_NAME --lock-level $MOODLE_MANAGED_APP_LOCK_LEVEL --display-name $MOODLE_MANAGED_APP_DISPLAY_NAME --description "$MOODLE_MANAGED_APP_DESCRIPTION" --authorizations="$MOODLE_MANAGED_APP_AUTHORIZATIONS" --main-template=@mainTemplate.json --create-ui-definition=@createUIDefinition.json
```

Results:

```
{
  "artifacts": [
    {
        "name": "ApplicationResourceTemplate",
        "type": "Template",
        "uri": "https://prdsapplianceprodsn01.blob.core.windows.net/applicationdefinitions/84205_325E7C3499FB4190AA871DF746C67705_6E0E9CA0060F5CEE88CC3E16F940540CBAA53157/applicationResourceTemplate.json?sv=2014-02-14&sr=b&sig=bKFLpLurcUVEspaICr158432gE6OSNCWPapzUUMcN3w%3D&se=2118-02-28T20:22:50Z&sp=r"
    },
    {
        "name": "CreateUiDefinition",
        "type": "Custom",
        "uri": "https://management.azure.com/subscriptions/325e7c34-99fb-4190-aa87-1df746c67705/resourceGroups/MoodleManagedAppRG/providers/Microsoft.Solutions/applicationDefinitions/MoodleManagedApp/applicationArtifacts/CreateUiDefinition?api-version=2017-09-01"
    }
  ],
  "authorizations": [
    {
        "principalId": "dd46cacd-eab1-43b0-a4ba-425d8b8d82fa",
        "roleDefinitionId": "8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
    }
  ],
  "createUiDefinition": null,
  "description": "Moodle on Azure as a Managed Application",
  "displayName": "Moodle",
  "id": "/subscriptions/325e7c34-99fb-4190-aa87-1df746c67705/resourceGroups/MoodleManagedAppRG/providers/Microsoft.Solutions/applicationDefinitions/MoodleManagedApp",
  "identity": null,
  "isEnabled": "True",
  "location": "southcentralus",
  "lockLevel": "ReadOnly",
  "mainTemplate": null,
  "managedBy": null,
  "name": "MoodleManagedApp",
  "packageFileUri": null,
  "resourceGroup": "MoodleManagedAppRG",
  "sku": null,
  "tags": null,
  "type": "Microsoft.Solutions/applicationDefinitions"
}
```

### [OPTIONAL] Package the files

The `mainTemplate.json` and `createUIDefinition.json` files can be
packaged together in a zip file. Both files should br at the root level
of the zip. Once created the package needs to be uploaded to a location accessible
to Azure. We've published the samples to GitHub so you can experiment
with minimal effort.

To use a package file remove the `--create-ui-definition` and
`--main-tamplate` arguments from the above CLI command instead provide
a URI for the package using `--package-file-uri` argument.

## Consume the Managed Application

Once the Moodle on Azure Managed Application is published to your
service catalog you can now depoloy it from within the portal or using
the CLI. In the following commands we'll see how to do this in the CLI.

### Setup a Resource Group for the Application

First we need to get the id of the application. This was returned in
the output of the command to create the service catalog entry.
However, we'll use the CLI to retireve it and record it into a
variable:

``` bash
MOODLE_MANAGED_APP_ID=$(az managedapp definition show --name $MOODLE_MANAGED_APP_NAME --resource-group $MOODLE_SERVICE_CATALOG_RG_NAME --query id --output tsv)
```

Create the application resource group, this is the group in which the
cusrtomer will see the managed application..

``` bash
az group create --name $MOODLE_DEPLOYMENT_RG_NAME --location=$MOODLE_DEPLOYMENT_LOCATION
```

Results:

``` json
{
    "id": "/subscriptions/325e7c34-99fb-4190-aa87-1df746c67705/resourceGroups/MoodleManagedApp",
    "location": "southcentralus",
    "managedBy": null,
    "name": "MoodleManagedApp",
    "properties": {
        "provisioningState": "Succeeded"
    },
    "tags": null
}
```

### Customer Deployment

When a customer wants to deploy an application they can do so using
either the Portal or the CLI. In this section we'll look at how this
is done in the CLI.

#### Providing Parameters

If we were using the portal our `CreateUIDefinition.json` file would
be used to create a user interface to define the parameters needed in
`mainTemplate.json`. When using the CLI we need to provide parameter
values for any parameters that don't have a default. To make it easier
to manage we'll put these parameter values into environment variables.

For convenience our `mainTemplate.json` file has defaults for all
values. This means that there is no need to provide parameters in the
commandline, though you can override the defaults if you want to by
adding the `--parameters` attribute. This attribute can take either 
a JSON string or a filename (preceded with an '@', e.g. '--parameters @parameters.json`) containing a JSON
definition for the paramters, e.g.


    {
        "parameterName": "value",
        "ANOtherParameter"" "another value"
    }


### Deploying the application

Deploy the managed application and corresponding infrastrcuture.

``` bash
az managedapp create --name $MOODLE_DEPLOYMENT_NAME --location $MOODLE_DEPLOYMENT_LOCATION --kind ServiceCatalog --resource-group $MOODLE_DEPLOYMENT_RG_NAME --managedapp-definition-id $MOODLE_MANAGED_APP_ID --managed-rg-id $MOODLE_MANAGED_RG_ID
```


