#!/bin/bash

# This script deploys AzLAMP containers on the AKS cluster that's deployed in an 
# Azure resource group by following https://github.com/Azure/Moodle/. This script
# assumes that the user is logged on to Azure using Azure CLI (e.g., Azure Cloud Shell)
# and the user's Azure subscription is set to the one where the resource group belongs
# to. If not, make sure to run the following commands prior to running this script:
#
# $ az login
# ...
# $ az account set --subscription <your_Azure_subscription_id_for_resource_group>

set -e

RESOURCE_GROUP=$1

if [ -z "$RESOURCE_GROUP" ]; then
    echo "Usage: $0 <resource_group>"
    exit 1
fi

(which jq &> /dev/null) || (sudo apt -y update; sudo apt -y install jq)
(which kubectl &> /dev/null) || (sudo az aks install-cli)
(which helm &> /dev/null) || (https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | sudo bash)

DEPLOYMENTS=$(az group deployment list --resource-group $RESOURCE_GROUP --query [].name -o tsv)

if (echo $DEPLOYMENTS | grep azuredeploy &> /dev/null); then
    DEPLOYMENT=azuredeploy
elif (echo $DEPLOYMENTS | grep Microsoft.Template &> /dev/null); then
    DEPLOYMENT=Microsoft.Template
else
    echo "Neither 'azuredeploy' nor 'Microsoft.Template' deployment exists in the resource group $RESOURCE_GROUP. Make sure to provide a valid resource group where https://github.com/Azure/Moodle/ templates were deployed. Exiting..."
    exit 1
fi

DEPLOYMENT_INFO=$(az group deployment show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT)
WEB_CLUSTER_TYPE=$(echo $DEPLOYMENT_INFO | jq -r .properties.parameters.webClusterType.value)
if [ "$WEB_CLUSTER_TYPE" != "AKS" ]; then
    echo "Web cluster type for this deployment is not AKS (it is $WEB_CLUSTER_TYPE), so we can't deploy containers! Exiting..."
    exit 1
fi

FILE_SERVER_TYPE=$(echo $DEPLOYMENT_INFO | jq -r .properties.parameters.fileServerType.value)
if [ "$FILE_SERVER_TYPE" != "nfs" -a "$FILE_SERVER_TYPE" != "nfs-ha" ]; then
    echo "Currently AKS web cluster supports nfs or nfs-ha fileServerType (it is $FILE_SERVER_TYPE), so we can't deploy containers! Exiting..."
    exit 1
fi

# Obtain needed helm chart deployment parameter values

# .Values.siteURL
SITE_URL=$(echo $DEPLOYMENT_INFO | jq -r .properties.outputs.siteURL.value)

# .Values.nfsStorageCapacity
FILE_SERVER_DISK_COUNT=$(echo $DEPLOYMENT_INFO | jq -r .properties.parameters.fileServerDiskCount.value)
FILE_SERVER_DISK_SIZE=$(echo $DEPLOYMENT_INFO | jq -r .properties.parameters.fileServerDiskSize.value)
let "FILE_SERVER_DISK_CAPACITY = $FILE_SERVER_DISK_COUNT * $FILE_SERVER_DISK_SIZE"
FILE_SERVER_DISK_CAPACITY="${FILE_SERVER_DISK_CAPACITY}Gi"

# .Values.nfsHost
VM_SETUP_PARAMS_OBJ=$(az group deployment show --resource-group $RESOURCE_GROUP --name vmSetupParamsTemplate --query properties.outputs.vmSetupParamsObj.value)
if [ "$FILE_SERVER_TYPE" = "nfs" ]; then
    NFS_HOST=$(echo $VM_SETUP_PARAMS_OBJ | jq -r .fileServerProfile.nfsVmName)
else # "$FILE_SERVER_TYPE" = "nfs-ha"
    NFS_HOST=$(echo $VM_SETUP_PARAMS_OBJ | jq -r .fileServerProfile.nfsHaLbIP)
fi

# .Values.replicaCount
AKS_INFO=$(az aks list --resource-group $RESOURCE_GROUP --query [0])
REPLICA_COUNT=$(echo $AKS_INFO | jq -r .agentPoolProfiles[0].count)

echo "Obtained necessary helm chart deployment parameters:"
echo "  .Values.siteURL            = $SITE_URL"
echo "  .Values.nfsStorageCapacity = $FILE_SERVER_DISK_CAPACITY"
echo "  .Values.nfsHost            = $NFS_HOST"
echo "  .Values.replicaCount       = $REPLICA_COUNT"
echo
echo "Deploying the helm chart..."
AKS_NAME=$(echo $AKS_INFO | jq -r .name)
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME
kubectl config use-context $AKS_NAME

helm init --wait
cd helm-charts
helm install azlamp --set siteURL=$SITE_URL,nfsStorageCapacity=$FILE_SERVER_DISK_CAPACITY,nfsHost=$NFS_HOST,replicaCount=$REPLICA_COUNT

echo "Helm chart installed! Now trying to assign DNS label ('$AKS_NAME') to the LB public IP..."
while true; do
    AKS_LB_PUB_IP=$(kubectl get services -o=jsonpath='{.items[?(@.metadata.name=="azlamp-web")].status.loadBalancer.ingress[0].ip}')
    if (echo $AKS_LB_PUB_IP | grep -E "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" &> /dev/null); then
        echo "Public IP ('$AKS_LB_PUB_IP') is assigned! Assigning DNS label ($AKS_NAME) to it..."
        AKS_RESOURCE_GROUP=$(echo $AKS_INFO | jq -r .nodeResourceGroup)
        AKS_LB_PUB_IP_NAME=$(az network public-ip list --resource-group $AKS_RESOURCE_GROUP --query "[?@.ipAddress=='$AKS_LB_PUB_IP'].name" -o tsv)
        az network public-ip update --resource-group $AKS_RESOURCE_GROUP --name $AKS_LB_PUB_IP_NAME --dns-name $AKS_NAME
        echo "Done assigning DNS label to the public IP! Exiting successfully..."
        exit 0
    fi
    echo "Public IP ('$AKS_LB_PUB_IP') is not yet assigned... Retrying in 15 seconds..."
    sleep 15
done
