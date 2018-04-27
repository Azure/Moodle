GITHUB_SLUG_BRANCH="${TRAVIS_REPO_SLUG}/${TRAVIS_BRANCH}"
if [ -n "$TRAVIS_PULL_REQUEST_SLUG" ]; then
  GITHUB_SLUG_BRANCH="${TRAVIS_PULL_REQUEST_SLUG}/${TRAVIS_PULL_REQUEST_BRANCH}"
fi
ARTIFACTS_LOCATION="https://raw.githubusercontent.com/${GITHUB_SLUG_BRANCH}/"
echo "ARTIFACTS_LOCATION=$ARTIFACTS_LOCATION"

echo "Running Azure build step."
az group deployment create --resource-group "$AZMDLGROUP" --template-file azuredeploy.json --parameters @azuredeploy.parameters.json sshPublicKey="$SPSSHKEY" _artifactsLocation="$ARTIFACTS_LOCATION" --no-wait

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
