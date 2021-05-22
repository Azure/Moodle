# Login to Azure

Before we start a load test session we need to first veriy that we are
logged in to Azure using the CLI.

## Azure Login

```Bash
az login --username $AZURE_USERNAME --password $AZURE_PASWORD
```

Note that if your username or password has any special characters in
it, such as '$' this may fail. You can login using a browser using `az login`.

```Bash
az account set --subscription $AZURE_SUBSCRIPTION_ID
```

## Validation

```Bash
az account show
```

Results:

```json
{
  "environmentName": "AzureCloud",
  "id": "325e7c34-99fb-4190-aa87-1df746c67705",
  "isDefault": true,
  "name": "Ross Dev Account",
  "state": "Enabled",
  "tenantId": "72f988bf-86f1-41af-91ab-2d7cd011db47",
  "user": {
    "name": "rogardle@microsoft.com",
    "type": "user"
  }
}
```
