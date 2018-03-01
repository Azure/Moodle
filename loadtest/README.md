# Load-Testing Deployed Moodle Cluster

This directory currently contains utility scripts, a Moodle test
course, and an Apache jMeter test plan that can be used to load-test a
Moodle cluster on Azure using the Azure Resource Manager templates in
this repository.

## Prerequisites

To run load tests using the resources in this directory, you'll want
to spin up an Ubuntu VM (let's call it the [Load Test VM](./Deploy_Load_Test_VM.md)) in your Azure subscription. This VM
will generate the traffic, running it in Azure will minimize network
charges.

## Deploying Moodle using templates and running load test

Once dependencies are installed, you can initiate the load testing
process by using included utility scripts. These scripts will:

  * deploy a Moodle cluster
  * set up the test course in Moodle
  * enrol students for the course
  * run a synthetic test workload using jMeter 
  * teardown the test cluster
  
Use the function `deploy_run_test1_teardown` to perform all these
steps. This function takes 17 parameters in the following order:

See the included example `run_load_test_example` in
`loadtest/loadtest.sh`. At the time of writing this example is
configured as follows:

``` bash
deploy_run_test1_teardown \
    ltest6 \
    southcentralus \
    https://raw.githubusercontent.com/Azure/Moodle/master/azuredeploy.json \
    azuredeploy.parameters.loadtest.defaults.json \
    apache \
    Standard_DS2_v2 \
    mysql \
    200 \
    125 \
    nfs \
    2 \
    128 \ 
    "$(cat ~/.ssh/authorized_keys)" \
    1600 \
    4800 \
    18000 
}
```

Running this example will deploy a cluster with the following configuration:

  * Apache web server
  * Standard_DS2_v2 Azure VM SKU
  * mysql database (with 200 DTU and 125GB DB size)
  * NFS file share (with 2 disks and 128GB disk size each)
  * uses your SSH pub key in `~/.ssh/id_rsa`

[NOTE ON SSH KEYS] Ensure your `~/.ssh/id_rsa` has been  added to ssh-agent using `eval $(ssh-agent)` and `ssh-add`). 

Once the Moodle cluster is deployed and configured with course and
student data (using [moosh](https://moosh-online.com/) it will run the
synthetic workload with designated number of concurrent threads (in
the example we use 1600 thread) for the designated duration and rampup
time (18000 seconds = 5 hours duration, 4800 seconds rampup time in
the example).

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
project. jMeter is a great load testing tool, and also thanks to [moosh](http://moosh-online.com/),
the whole process could be automated without too much difficulty, which was
really nice.
