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

```
MOODLE_RG_NAME=loadtest
```

And we'll need a name for our load test VM:

```
MOODLE_LOAD_TEST_VM_NAME=LoadTestVM
```

## Deploy the Load Test VM

First you need a resource group within which all your resources will be deployed.

``` bash
az group create --name $MOODLE_RG_NAME --location $MOODLE_RG_LOCATION
```

Now we can create our VM in this group. The following command will
create the VM and, if necessary, generate the SSH keys.

``` bash
az vm create --resource-group $MOODLE_RG_NAME --name $MOODLE_LOAD_TEST_VM_NAME --image UbuntuLTS --generate-ssh-keys
```

Results:

``` json
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

``` bash
ipAddress=$(az network public-ip show --name ${MOODLE_LOAD_TEST_VM_NAME}PublicIP --resource-group $MOODLE_RG_NAME --query "ipAddress" --output tsv)
echo $ipAddress
```

We can now connect to the VM using ssh, and run commands. The first thing we want to do is pull down the Moodle on Azure repo. Since this document is used to automatically run tests all our commands need to be non-interactive. We will therefore skip the host key validation step. Note that you should never do this in a production environment (remove `-o StrictHostKeyChecking=no`):

``` bash
ssh -o StrictHostKeyChecking=no $ipAddress git clone git://github.com/Azure/Moodle.git
```

Results:

```
Cloning into 'Moodle'...
```

At the time of writing the load test code has not been merged into
Master, so we need to switch to the right branch.

```
ssh -o StrictHostKeyChecking=no $ipAddress "cd Moodle; git checkout master"
```

Now we can install the load testing scripts and its dependencies:

``` bash
ssh -o StrictHostKeyChecking=no $ipAddress "cd Moodle/loadtest; . loadtest.sh; . loadtest.sh; install_java_and_jmeter; install_az_cli"
```


## Validation

Finally, we will verify that key dependencies have been installed. First lets check Java is present:

``` bash
ssh -o StrictHostKeyChecking=no $ipAddress "java -version"
```

Results:

```
openjdk version "1.8.0_151"
OpenJDK Runtime Environment (build 1.8.0_151-8u151-b12-0ubuntu0.16.04.2-b12)
OpenJDK 64-Bit Server VM (build 25.151-b12, mixed mode)
```

We will also need to confirm the Azure CLI is present:

``` bash
ssh -o StrictHostKeyChecking=no $ipAddress "az --version"
```

Results:

```
azure-cli (2.0.27)

acr (2.0.21)
acs (2.0.26)
advisor (0.1.2)
appservice (0.1.26)
backup (1.0.6)
batch (3.1.10)
batchai (0.1.5)
billing (0.1.7)
cdn (0.0.13)
cloud (2.0.12)
cognitiveservices (0.1.10)
command-modules-nspkg (2.0.1)
configure (2.0.14)
consumption (0.2.1)
container (0.1.18)
core (2.0.27)
cosmosdb (0.1.19)
dla (0.0.18)
dls (0.0.19)
eventgrid (0.1.10)
extension (0.0.9)
feedback (2.1.0)
find (0.2.8)
interactive (0.3.16)
iot (0.1.17)
keyvault (2.0.18)
lab (0.0.17)
monitor (0.1.2)
network (2.0.23)
nspkg (3.0.1)
profile (2.0.19)
rdbms (0.0.12)
redis (0.2.11)
reservations (0.1.1)
resource (2.0.23)
role (2.0.19)
servicefabric (0.0.10)
sql (2.0.21)
storage (2.0.25)
vm (2.0.26)

Python location '/home/rgardler/lib/azure-cli/bin/python'
Extensions directory '/home/rgardler/.azure/cliextensions'

Python (Linux) 2.7.12 (default, Dec  4 2017, 14:50:18)
[GCC 5.4.0 20160609]

Legal docs and information: aka.ms/AzureCliLegal
```






