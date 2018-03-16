# Cleaning up a Test Deployment

If you worked through the documentation in this section you will have
created a nubmer of resources and at least one entry into your Service
Catalog. This document will explain how to remove them all.

## Prerequisites

We need to ensure the [variables](Environment.md) are set up correctly.

## Azure Active Directory

``` bash
MOODLE_MANAGED_APP_AD_ID=$(az ad group list --filter="displayName eq '$MOODLE_MANAGED_APP_OWNER_GROUP_NAME'" --query [*].objectId --output tsv)
az ad group delete --group $MOODLE_MANAGED_APP_AD_ID
```

## Remove the Service Catalog Entry

``` bash
az managedapp definition delete --resource-group $MOODLE_SERVICE_CATALOG_RG_NAME --ids $MOODLE_MANAGED_APP_ID
```

### Service catalog resource group

If you create a resource group solely for the managed application you
are now deleting you can safely remove its resource group:

``` bash
az group delete --name $MOODLE_SERVICE_CATALOG_RG_NAME --yes
```

## Managed Application

By deleting the managed application Azure will automatically delete
the managed application infrastructure resource group as well (this
was created as part of the managed application deployment).

First we need the application ID.

``` bash
MOODLE_DEPLOYMENT_ID=$(az managedapp show --resource-group $MOODLE_DEPLOYMENT_RG_NAME --name $MOODLE_DEPLOYMENT_NAME)
```

Now we have the ID we can delete the application.

``` bash
az managedapp delete --resource-group $MOODLE_DEPLOYMENT_RG_NAME --ids $MOODLE_DEPLOYMENT_ID
```

