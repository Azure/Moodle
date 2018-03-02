# Setup Environment

For convenience most of the configuration values we need to create and
manage our Moodle Managed Application we'll create a numer of
Environment Variables. In order to store any generated files and
configurations we will also create a workspace.

NOTE: If you are running these scripts through SimDem you can
customize these values by copying and editing `env.json` into
`env.local.json`.

## Setup for Publishing the Moodle Managed Application

``` bash
MOODLE_MANAGED_APP_OWNER_GROUP_NAME=MoodleOwner
MOODLE_MANAGED_APP_OWNER_NICKNAME=MoodleOwner
MOODLE_SERVICE_CATALOG_LOCATION=southcentralus
MOODLE_SERVICE_CATALOG_RG_NAME=MoodleManagedAppRG
MOODLE_MANAGED_APP_NAME=MoodleManagedApp
MOODLE_MANAGED_APP_LOCK_LEVEL=ReadOnly
MOODLE_MANAGED_APP_DISPLAY_NAME=Moodle
MOODLE_MANAGED_APP_DESCRIPTION="Moodle on Azure as a Managed Application"
```

## Setup for Consuming the Moodle Managed Application

Create an id for the resource group that will be managed by the
managed application provider. This is the resource group that
infrastructure will be deployed into. The end user does not,
generally, manage this group.

``` bash
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
MOODLE_MANAGED_RG_ID=/subscriptions/$SUBSCRIPTION_ID/resourceGroups/MoodleInfrastructure
```

We'll also need a resource group for the application deployment. This is the
resource group into which the application is deployed. This is the resource group that
the provider of the managed application will have access to.

``` bash
MOODLE_DEPLOYMENT_RG_NAME=MoodleManagedAppRG
MOODLE_DEPLOYMENT_LOCATION=southcentralus
MOODLE_DEPLOYMENT_NAME=MoodleManagedApp
```

## Workspace

We need a workspace for storing configuration files and other
per-deployment artifacts:

``` shell
MOODLE_MANAGED_APP_WORKSPACE=~/.moodle
mkdir -p $MOODLE_MANAGED_APP_WORKSPACE/$MOODLE_DEPLOYMENT_NAME
```

## SSH Key

We use SSH for secure communication with our hosts. The following line
will check there is a valid SSH key available and, if not, create one.

```
MOODLE_SSH_KEY_FILENAME=~/.ssh/moodle_managedapp_id_rsa
if [ ! -f "$MOODLE_SSH_KEY_FILENAME" ]; then ssh-keygen -t rsa -N "" -f $MOODLE_SSH_KEY_FILENAME; fi
```
