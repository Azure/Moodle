# Load-Testing Deployed Moodle Cluster

This directory currently contains utility scripts, a Moodle test
course, and an Apache jMeter test plan that can be used to load-test a
Moodle cluster on Azure using the Azure Resource Manager templates in
this repository.

## Prerequisites

To run load tests using the resources in this directory, you'll want
to spin up a VM to manage the [Load Test](Deploy_Load_Test_VM.md) in
your Azure subscription. This VM will generate the traffic, running it
in Azure will minimize network charges.

## Deploying Moodle using templates and running load test

Once dependencies are installed, you can initiate the load testing
process by using included utility scripts. These scripts will:

* deploy a Moodle cluster
* set up the test course in Moodle
* enrol students for the course
* run a synthetic test workload using jMeter
* teardown the test cluster

Use the function `deploy_run_test1_teardown` to perform all these
steps. This function takes 18 parameters in the following order:

See the included example `run_load_test_example` in
`loadtest/loadtest.sh`. At the time of writing this example is
configured as follows:

``` bash
ssh $ipAddress "az login --username $AZURE_LOGIN --password $AZURE_PASSWORD; az account set --subscription $AZURE_SUBSCRIPTION_ID; run_load_test_example"
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

## Test plans

We'd like to offer test plans that are as realistic as possible, so that potential
Moodle users on Azure can have better confidence with their Moodle deployment on Azure.
We are just starting out in that direction and here are descriptions of currently
available test plans.

### Simple Scenario [simple-test-1.jmx](./simple-test-1.jmx)

This test plan is a simple scenario that performs the following operations repeatedly:

* Login to the Moodle site
* View the test course
* View any resource if any
* View a forum in the test course
* View any forum discussion
* Post a new discussion topic
* Take a quiz and submit

The scripts in [loadtest.sh](./loadtest.sh) are tailored for this test plan.

### Moodle Data Stress Testing [simple-test-2.jmx](./simple-test-2.jmx)

Currently [loadtest.sh](./loadtest.sh) doesn't have any tailored scripts for this
test plan. Therefore, this test plan will need to be executed by issuing the
actual jmeter command with properly modified parameters manually, or it'd be
greatly appreciated if someone can contribute better support for this test plan
in [loadtest.hs](./loadtest.sh).

The purpose of this test plan is to try stressing the moodledata directory
in a shared file system (either a gluster volume or an NFS share, depending
on the choice). Initially attaching a random file in a forum discussion post
was tried, but for some reason (probably due to my lack of understanding
in PHP/web interaction), files were not attached. I instead tried to upload
random files to each test Moodle users's Private Files area, and it did work.
This test plan basically performs the following operations repeatedly:

* Login to the Moodle site
* Open the Moodle user's Private Files repository
* Upload a randomly generated file (of a random size within a hard-coded range)
* Save the change

This way, we were able to populate the shared moodledata directory with
random files in Moodle users' Private Files repositories. The mechanism
to generate random files is not so efficient, so that's currently what
slows down the upload speed, and any improvement in that BeanShell preprocessor
code would be great. Note that the uploaded files have to be different.
Moodle seems so good at deduplicating that a single file uploaded multiple
times by different users won't increase the file system usage beyond its
single copy.

It'd be also great if we add a download operation step in the test plan,
and it's left as a future work item.

### Latency-Sensitive Stress Testing [time-gated-exam-test.jmx](./time-gated-exam-test.jmx)

This test stresses the deployed Moodle cluster with 1000 emulated students
trying to get in an exam (quiz) that's initially closed and will be opened
at the designated exam start time (have to be manually set on the test course's
corresponding quiz's Settings). Once the exam start time passes, each emulated
student continues taking the exam for 10 times.

This test has been used to find out how responsive
a deployed Moodle cluster can be on very latency-sensitive workloads. We've been
using this test with different file server types to find out which file server
type offers best response times.

## Please contribute

It'd be great if we have more test plans, and make other parameters configurable (for
example, make the auto-scaling thresholds configurable, which actually requires
some changes in the templates as well). The currently available test plans
also have hard-coded database type (JDBC connection string) that won't work
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
