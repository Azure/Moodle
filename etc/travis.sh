#!/bin/bash

set -ev

# Run the lint tests, then if env vars are present validate the template then try building the stack.
npm test

if [ -z "$SPNAME" -o -z "$SPPASSWORD" -o -z "$SPTENANT" -o -z "$SPSSHKEY" ]; then
  echo "No Azure deployment info given, skipping test deployment and exiting..."
  exit 0
fi

export RUNBUILD="true"
export AZMDLGROUP="azmdl-travis-$TRAVIS_BUILD_NUMBER"

if [ -z "$LOCATION" ]; then
  export LOCATION="southcentralus"
fi

echo "Running Azure setup steps."
az login --service-principal -u "$SPNAME" -p "$SPPASSWORD" --tenant "$SPTENANT"
az group create -l "$LOCATION" -g "$AZMDLGROUP"

echo "Running Azure validation step."
VALIDATION_RESULT=$(az group deployment validate --resource-group "$AZMDLGROUP" --template-file azuredeploy.json --parameters azuredeploy.parameters.json --parameters sshPublicKey="$SPSSHKEY" --query error)
if [ -n "$VALIDATION_RESULT" ]; then
  echo "Azure template validation failed! Error message:"
  echo $VALIDATION_RESULT
  exit 1
fi

echo "Running Azure build step."
az group deployment create --resource-group "$AZMDLGROUP" --template-file azuredeploy.json --parameters @azuredeploy.parameters.json sshPublicKey="$SPSSHKEY"

while true; do
  echo -n .
  sleep 30
  PROV_STATE=$(az group deployment show -g $AZMDLGROUP -n azuredeploy --query properties.provisioningState -o tsv)
  if [ "$PROV_STATE" != "Running" ]; then
    echo "Provisioning state is now non-running ('$PROV_STATE'), stop polling"
    break
  fi
done

if [ "$PROV_STATE" != "Succeeded" ]; then
  DEPL_ERROR=$(az group deployment show -g $AZMDLGROUP -n azuredeploy --query error)
  echo "Azure deployment failed! Error message:"
  echo $DEPL_ERROR
  exit 1
else
  DEPL_OUTPUT=$(az group deployment show -g $AZMDLGROUP -n azuredeploy)
  echo "Azure deployment succeeded! Deployment results:"
  echo $DEPL_OUTPUT
  exit 0
fi
