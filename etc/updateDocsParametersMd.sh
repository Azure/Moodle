#!/bin/bash

# Should be run at the git repo root as: $ ./etc/updateDocsParameters.sh

dpkg -l jq &> /dev/null || sudo apt install jq

sed -i '/## Available Parameters/q' docs/Parameters.md
echo >> docs/Parameters.md
jq -r '.parameters | to_entries[] | "### " + .key + "\n\n" + .value.metadata.description + "\n\nType: " + .value.type + "\n\nPossible Values: " + (.value.allowedValues | @text) + "\n\nDefault: " + (.value.defaultValue | @text) + "\n\n"' azuredeploy.json >> docs/Parameters.md 