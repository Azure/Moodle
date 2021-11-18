# This script will create a Managed Application from the Azure/Moodle ARM template
# see https://github.com/Azure/Moodle/tree/master/managedApplication

# Application Configuration

export VERSION_NUMBER=1
export MOODLE_MANAGED_APP_DISPLAY_NAME=MoodleManagedApp
export MOODLE_MANAGED_APP_NAME=MoodleManagedApp_$(whoami)_$VERSION_NUMBER
export MOODLE_MANAGED_APP_DESCRIPTION="Testing the Moodle ARM template as a managed application."
export MOODLE_MANAGED_APP_OWNER_GROUP_NAME=$MOODLE_MANAGED_APP_NAME
export MOODLE_MANAGED_APP_OWNER_NICKNAME=$MOODLE_MANAGED_APP_NAME
export MOODLE_SERVICE_CATALOG_RG_NAME=Catalog_RG_$MOODLE_MANAGED_APP_NAME
export MOODLE_MANAGED_APP_LOCK_LEVEL=None
export MOODLE_SERVICE_CATALOG_LOCATION=WestUS

export PATH_TO_ARM_TEMPLATE=../azuredeploy.json
export PATH_TO_MOODLE_CREATEUI_DEF=createUIDefinition.json

# Publish A Managed Application To Service Catalog

# AD Config

echo "Configuring AD"

echo "Getting Application AD ID for $MOODLE_MANAGED_APP_OWNER_GROUP_NAME"

MOODLE_MANAGED_APP_AD_ID=$(az ad group list --display-name=$MOODLE_MANAGED_APP_OWNER_GROUP_NAME --query [0].objectId --output tsv)

# The following line should create a new group, if necessary, but it fails with insufficient permissions
# if [ -z "$MOODLE_MANAGED_APP_AD_ID" ]; then az ad group create --display-name $MOODLE_MANAGED_APP_OWNER_GROUP_NAME --mail-nickname=$MOODLE_MANAGED_APP_OWNER_NICKNAME; fi
# Not sure how to fix it so, for now tell user to create in portal, which works fine
if [ -z "$MOODLE_MANAGED_APP_AD_ID" ]
then
    echo "AD group doesn't exist.\n"
    echo "There's a bug in the script which prevents this being automated (see comments, should be fixable by someone who knows)\n"
    echo "For now, you need to create an ad group with the name $MOODLE_MANAGED_APP_OWNER_GROUP_NAME and owner $MOODLE_MANAGED_APP_OWNER_NICKNAME see https://ms.portal.azure.com/#blade/Microsoft_AAD_IAM/GroupsManagementMenuBlade/AllGroups"
    read -p "Press any key when done... " -n1 -s;
    echo "Continuing..."
    MOODLE_MANAGED_APP_AD_ID=$(az ad group list --display-name=$MOODLE_MANAGED_APP_OWNER_GROUP_NAME --query [0].objectId --output tsv)
fi

if [ -z "$MOODLE_MANAGED_APP_AD_ID"]
then
    >&2 echo "Failed to get a Managed App AD ID. If you just created this it may be that it is still propogating. Rerun the script."
    exit 1
else
    echo "Managed App AD ID is $MOODLE_MANAGED_APP_AD_ID"
fi

MOODLE_MANAGED_APP_ROLE_ID=$(az role definition list --name Owner --query [].name --output tsv)

echo "Managed App Role ID is $MOODLE_MANAGED_APP_ROLE_ID"

# Create a Resource Group

echo "Creating the resource group for the service catalog using the name $MOODLE_SERVICE_CATALOG_RG_NAME and location $MOODLE_SERVICE_CATALOG_LOCATION"

az group create --name $MOODLE_SERVICE_CATALOG_RG_NAME --location $MOODLE_SERVICE_CATALOG_LOCATION

# Publish to the Service Catalog

echo "Publishing the application to the service catalog using the name $MOODLE_MANAGED_APP_NAME"

MOODLE_MANAGED_APP_AUTHORIZATIONS=$MOODLE_MANAGED_APP_AD_ID:$MOODLE_MANAGED_APP_ROLE_ID

az managedapp definition create \
    --name $MOODLE_MANAGED_APP_NAME \
    --location $MOODLE_SERVICE_CATALOG_LOCATION \
    --resource-group $MOODLE_SERVICE_CATALOG_RG_NAME \
    --lock-level $MOODLE_MANAGED_APP_LOCK_LEVEL \
    --display-name $MOODLE_MANAGED_APP_DISPLAY_NAME \
    --description "$MOODLE_MANAGED_APP_DESCRIPTION" \
    --authorizations="$MOODLE_MANAGED_APP_AUTHORIZATIONS" \
    --main-template=@$PATH_TO_ARM_TEMPLATE \
    --create-ui-definition=@$PATH_TO_MOODLE_CREATEUI_DEF


MOODLE_MANAGED_APP_ID=$(az managedapp definition show --name $MOODLE_MANAGED_APP_NAME --resource-group $MOODLE_SERVICE_CATALOG_RG_NAME --query id --output tsv)

echo
echo "###############################################################"
echo "Assuming no errors reporteed above, you can now deploy an application in the portal at https://ms.portal.azure.com/#blade/HubsExtension/BrowseResource/resourceType/Microsoft.Solutions%2FapplicationDefinitions"
echo "###############################################################"
