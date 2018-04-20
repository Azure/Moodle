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
  export LOCATION="westus"
fi

echo "Running Azure setup steps."
az login --service-principal -u "$SPNAME" -p "$SPPASSWORD" --tenant "$SPTENANT"
az group create -l "$LOCATION" -g "$AZMDLGROUP"

echo "Running Azure validation step."
VALIDATION_RESULT=$(az group deployment validate --resource-group "$AZMDLGROUP" --template-file azuredeploy.json --parameters azuredeploy.parameters.json --parameters sshPublicKey="$SPSSHKEY")
if [ -n "$VALIDATION_RESULT" ]; then
  echo "Azure template validation failed! Error message:"
  echo $VALIDATION_RESULT
  exit 1
fi

echo "Running Azure build step."
az group deployment create --resource-group "$AZMDLGROUP" --template-file azuredeploy.json --parameters azuredeploy.parameters.json --parameters sshPublicKey="$SPSSHKEY" --debug --verbose
