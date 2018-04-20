#!/bin/bash

set -ev

# Run the lint tests, then if env vars are present validate the template then try building the stack.
npm test

AZMDLGROUP="azmdl-travis-$TRAVIS_BUILD_NUMBER"
echo "AZMDLGROUP=$AZMDLGROUP"

if [ -z "$LOCATION" ]; then
  LOCATION="southcentralus"
fi
echo "LOCATION=$LOCATION"

GITHUB_SLUG_BRANCH="${TRAVIS_REPO_SLUG}/${TRAVIS_BRANCH}"
if [ -n "$TRAVIS_PULL_REQUEST_SLUG" ]; then
  GITHUB_SLUG_BRANCH="${TRAVIS_PULL_REQUEST_SLUG}/${TRAVIS_PULL_REQUEST_BRANCH}"
fi
ARTIFACTS_LOCATION="https://raw.githubusercontent.com/${GITHUB_SLUG_BRANCH}/"
echo "ARTIFACTS_LOCATION=$ARTIFACTS_LOCATION"

if [ -z "$SPNAME" -o -z "$SPPASSWORD" -o -z "$SPTENANT" -o -z "$SPSSHKEY" ]; then
  echo "No Azure deployment info given, skipping test deployment and exiting..."
  exit 0
fi

echo "Running Azure setup steps."
az login --service-principal -u "$SPNAME" -p "$SPPASSWORD" --tenant "$SPTENANT"
az group create -l "$LOCATION" -g "$AZMDLGROUP"

echo "Running Azure validation step."
VALIDATION_RESULT=$(az group deployment validate --resource-group "$AZMDLGROUP" --template-file azuredeploy.json --parameters @azuredeploy.parameters.json sshPublicKey="$SPSSHKEY" _artifactsLocation="$GITHUB_SLUG_BRANCH" --query error)
if [ -n "$VALIDATION_RESULT" ]; then
  echo "Azure template validation failed! Error message:"
  echo $VALIDATION_RESULT
  exit 1
fi

echo "Running Azure build step."
az group deployment create --resource-group "$AZMDLGROUP" --template-file azuredeploy.json --parameters @azuredeploy.parameters.json sshPublicKey="$SPSSHKEY" _artifactsLocation="$GITHUB_SLUG_BRANCH" --no-wait

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
