# Load-Testing Deployed Moodle Cluster

This directory currently contains utility scripts, a Moodle test course,
and a jMeter test plan that can be used to load-test a Moodle cluster
that's deployed on Azure using the templates in this repo.

## Setting up the test host

To run load tests using the resources in this directory, you'll want to spin up
an Ubuntu 16.04 Linux VM on your Azure subscription and an Azure location where
you'll be deploying your Moodle cluster (so that test traffic can be from the
same Azure region to avoid egress charges). Once your Ubuntu 16.04 Linux VM is
ready, you need to install Java and [jMeter](https://jmeter.apache.org/).
You also need the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) 
installed on your Ubuntu 16.04 Linux VM (let's call it the jMeter host) for 
necessary Azure operations (deployment, metadata retrieval).
These dependencies can be installed using the included utility scripts as follows:
```
$ cd [local_repo]/loadtest
$ . loadtest.sh
$ install_java_and_jmeter
$ install_az_cli
```
Steps above need to be performed only once.

## Deploying Moodle using templates and running load test

Once dependencies are installed, you can initiate the whole process of a load 
testing process using included utility scripts,
starting from a whole Moodle cluter template deployment, setting up the test course
and enrolling students on the Moodle host, and running the synthetic test workload
using jMeter. See the included example `run_load_test_example` that's as follows:
```
function run_load_test_example
{
    check_ssh_agent_and_added_key || return 1

    deploy_run_test1_teardown ltest6 southcentralus https://raw.githubusercontent.com/Azure/Moodle/hs-loadtest/azuredeploy.json azuredeploy.parameters.loadtest.defaults.json apache Standard_DS2_v2 mysql 200 125 nfs 2 128 "$(cat ~/.ssh/authorized_keys)" 1600 4800 18000
}
```
Running the script function above will deploy the templates with Apache web server,
Standard_DS2_v2 Azure VM SKU, mysql database (with 200 DTU and 125GB DB size),
NFS file share (with 2 disks and 128GB disk size each), using your SSH pub key in
your home directory (make sure to copy the corresponding SSH private key as 
`~/.ssh/id_rsa` and have it added to ssh-agent using `eval $(ssh-agent)` and 
`ssh-add`). Once the template deployment is successfully completed, the script
will configure the deployed Moodle server with a test course and test students
(installing/running [moosh](https://moosh-online.com/) on the Moodle host over ssh),
and finally run the synthetic workload with designated number of concurrent threads 
(1600 above) and the time duration of the simulation run (18000 seconds=5 hours, and 
4800 seconds rampup time---make sure to give a sufficient rampup time for the number 
of concurrent threads).

## Please contribute!

It'd be great if we have other test plans (like uploading files populating the
`moodledata` directory intensely), and make other parameters configurable (for
example, make the auto-scaling thresholds configurable, which actually requires
some changes in the templates as well). The currently available test plan
also has hard-coded database type (JDBC connection string) that won't work
for Postgres SQL server, so making it work would be also greatly appreciated.
Also, if you run this load test with any parameters, it'd be great to share
the numeric results so that we can have more performance data on various
configurations. Here is [a link to an Excel spreadsheet](https://1drv.ms/x/s!Aj6KpM6lFGAjgd4D6IV8_6M42q9omA)
where anyone can share their load testing results.

## Acknowledgement

The original test course and the test plan were generously provided by
[Catalyst](https://github.com/catalyst) as part of this template modernization
project. jMeter is a great load testing tool, and also thanks to moosh,
the whole process could be automated without too much difficulty, which was
really nice.