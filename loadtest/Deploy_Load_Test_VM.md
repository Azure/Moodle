# Setting up a test host

To run load tests using the resources in this directory, you'll want
to spin up an Ubuntu VM (let's call it the jMeter host) in your Azure
subscription. This should be located in the same region as your Moodle
cluster in order to avoid egress charges. Once your VM is ready, you
need to install Java and [jMeter](https://jmeter.apache.org/).

## Prerequisites

To make things consistent across different sessions load testing Moodle we
should [configure the moodle environment](../docs/Preparation.md).

We will want to use a consistent resource group name in order to avoid
wasting resource in these tests:

```Bash
MOODLE_RG_NAME=loadtest
```

And we'll need a name for our load test VM:

```Bash
MOODLE_LOAD_TEST_VM_NAME=LoadTestVM
```

## Deploy the Load Test VM

First you need a resource group within which all your resources will be deployed.

```Bash
az group create --name $MOODLE_RG_NAME --location $MOODLE_RG_LOCATION
```

Now we can create our VM in this group. The following command will
create the VM and, if necessary, generate the SSH keys.

```Bash
az vm create --resource-group $MOODLE_RG_NAME --name $MOODLE_LOAD_TEST_VM_NAME --image UbuntuLTS --generate-ssh-keys
```

Results:

```json
{
  "fqdns": "",
  "id": "/subscriptions/325e7c34-99fb-4190-aa87-1df746c67705/resourceGroups/loadtestvm/providers/Microsoft.Compute/virtualMachines/LoadTestVM",
  "location": "southcentralus",
  "macAddress": "00-0D-3A-70-91-57",
  "powerState": "VM running",
  "privateIpAddress": "10.0.0.4",
  "publicIpAddress": "13.84.131.173",
  "resourceGroup": "loadtestvm",
  "zones": ""
}
```

You will need the IP number from this output. For convenience we'll
place it into an environment variable:

```Bash
ipAddress=$(az network public-ip show --name ${MOODLE_LOAD_TEST_VM_NAME}PublicIP --resource-group $MOODLE_RG_NAME --query "ipAddress" --output tsv)
echo $ipAddress
```

We can now connect to the VM using ssh, and run commands. The first thing we want to do is pull down the Moodle on Azure repo. Since this document is used to automatically run tests all our commands need to be non-interactive. We will therefore skip the host key validation step. Note that you should never do this in a production environment (remove `-o StrictHostKeyChecking=no`):

```Bash
ssh -o StrictHostKeyChecking=no $ipAddress "rm -Rf Moodle; git clone git://github.com/Azure/Moodle.git"
```

Now we can install the load testing scripts, we will have these loaded
via the `.profile` so that they are always availble.

```Bash
ssh $ipAddress 'echo ". ~/Moodle/loadtest/loadtest.sh" >> ~/.profile'
```

This script provides some helper functions for installing dependencies
on the VM.

```Bash
ssh $ipAddress 'install_java_and_jmeter; install_az_cli'
```

We need to login to Azure using the CLI. The command below is
convenient but is not secure since it stores your password in clear
text in an environment variable. However, it is convenient for test
purposes.

```Bash
ssh $ipAddress "az login --username $AZURE_LOGIN --password $AZURE_PASSWORD; az account set --subscription $AZURE_SUBSCRIPTION_ID"
```

## Validation

Finally, we will verify that key dependencies have been installed. First lets check Java is present:

```Bash
ssh -o StrictHostKeyChecking=no $ipAddress "java -version"
```

Results:

> openjdk version "1.8.0_151"
> OpenJDK Runtime Environment (build 1.8.0_151-8u151-b12-0ubuntu0.16.04.2-b12)
> OpenJDK 64-Bit Server VM (build 25.151-b12, mixed mode)

We will also need to confirm the Azure CLI is present:

```Bash
ssh -o StrictHostKeyChecking=no $ipAddress "if hash az 2>/dev/null; then echo "Azure CLI Installed"; else echo "Missing dependency: Azure CLI"; fi"
```

Results:

> Azure CLI Installed
