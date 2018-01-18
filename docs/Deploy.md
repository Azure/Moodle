# Deploy Autoscaling Moodle Stack to Azure

After following the steps in this this document you with awill have a
new Moodle site with caching for speed and scaling frontends to handle
load. The filesystem behind it is mirrored for high availability and
optionally backed up through Azure. Filesystem permissions and options
have also been tuned to make Moodle more secure than a default
install.

## Prerequisites

You will need a local copy of the Moodle ARM templates. These are
published on GitHub so you should clone them locally (possibly after
forking them on GitHub).

## Create Resource Group

When you create the Moodle cluster you will create many resources. On
Azure it is a best practice to collect such resources together in a
Resource Group. The first thing we need to do, therefore, is create a
resource group:

```
az group create --name $MOODLE_RG_NAME --location $MOODLE_RG_LOCATION
```

Results:

```expected_similarity=0.4
{
  "id": "/subscriptions/325e7c34-99fb-4190-aa87-1df746c67705/resourceGroups/rgmoodlearm3",
  "location": "westus2",
  "managedBy": null,
  "name": "rgmoodlearm3",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null
}
```

## Create Azure Deployment Paramaters

Your deployment will be configured using an
`azuredeploy.parameters.json` file. It is possible to provide these
parameters interactively via the command line by simply omitting the
paramaters file in the command in the next section. However, it is
more reproducible if we use a paramaters file.

A good set of defaults are provided in the git repository. These
defaults create a scalable cluster that is suitable for low volume
testing. If you are building out a production service you should
review the section below on sizing considerations. For now we will
proceed with the defaults, but there is one value, the `sshPublicKey`
that **must** be provided. To automatically add your default SSH key
(in Bash) use the following command:

```
FIXME: sed command to add SSH key
```

## Deploy cluster

Now that we have a resource group and a configuration file we can
create the cluster itself. This is done with a single command:

```
az group deployment create --name $MOODLE_DEPLOYMENT_NAME --resource-group $MOODLE_RG_NAME --template-file ~/projects/azure-quickstart-templates/moodle-scalable-cluster-ubuntu/azuredeploy.json --parameters azuredeploy.parameters.json
```

## Using the created stack

In testing, stacks typically took between 1 and 2 hours to finish,
depending on spec. Once complete you will receive a JSON output
containing information needed to manage your Moodle install (see
`outputs`). You can also retrieve this infromation from the portal or
the CLI.
                      
Once Moodle has been created, and (where necessary) you have
configured your custom `siteURL` DNS to point to the
`loadBalancerDNS`, you should be able to load the `siteURL` in a
browser and login with the username "admin" and the
`moodleAdminPassword`. Note that the values for each of these
parameters are avialble in the portal or the `outputs` section of the
JSON response from the previous deploy command. See [documentation on
how to retrieve configuration data](./Get-Install-Data.md) along
with full details of all the output parameters avialble to you.

Note that by default the deployment uses a self-signed certificate,
consequently you will recieve a warning when accessing the site. To
add a genuine certificate see the documentation on [managing your
cluster](./Manage.md).

## Sizing Considerations and Limitations

Depending on what you're doing with Moodle you will want to configure
your deployment appropriately.The defaults included produce a cluster
that is inexpensive but probably too low spec to use beyond simple
testing scenarios. This section includes an overview of how to size
the database and VM instances for your use case.

It should be noted that as of the time of this writing both Postgres
and MySQL databases are in preview at Azure. In the future larger DB
sizes or different VM sizes will be available. The templates will
allow you to select whatever size you want, but there are restrictions
in place (VMs with certain storage types, disk size for database
tiers, etc) that may prevent certains selections from working
together.

### Database Sizing

As of the time of this writing, Azure supports "Basic" and "Standard"
tiers for database instances. In addition the skuCapacityDTU defines
Compute Units, and the number of those you can use is limited by
database tier:

- Basic: 50, 100
- Standard: 100, 200, 400, 800

This value also limits the maximum number of connections, as defined
here: https://docs.microsoft.com/en-us/azure/mysql/concepts-limits

As the Moodle database will handle cron processes as well as the
website, any public facing website with more than 10 users will likely
require upgrading to 100. Once the site reaches 30+ users it will
require upgrading to Standard for more compute units. This depends
entirely on the individual site. As MySQL databases cannot change (or
be restored to a different tier) once deployed it is a good idea to
slightly overspec your database.

Standard instances have a minimum storage requirement of 128000MB. All
database storage, regardless of tier, has a hard upper limit of 1
terrabyte. After 128GB you gain additional iops for each GB, so if
you're expecting a heavy amount of traffic you will want to oversize
your storage. The current maximum iops with a 1TB disk is 3000.

### Controller instance sizing

The controller handles both syslog and cron duties. Depending on how
big your Moodle cron runs are this may not be sufficient. If cron jobs
are very delayed and cron processes are building up on the controller
then an upgrade in tier is needed.

### Frontend instances

In general the frontend instances will not be the source of any
bottlenecks unless they are severely undersized versus the rest of the
cluster. More powerful instances will be needed should fpm processes
spawn and exhaust memory during periods of heavy site load. This can
also be mitigated against by increasing the number of VMs but spawning
new VMs is slower (and potentially more expensive) than having that
capacity already available.

It is worth noting that the memory allowances on these instances allow
for more memory than they may be able to provide with lower instance
tiers. This is intentional as you can opt to run larger VMs with more
memory and not require manual configuration. FPM also allows for a
very large number of threads which prevents the system from failing
during many small jobs.


## Next Steps

  1. [Retrieve configuration details using CLI](./Get-Install-Data.md)
  1. [Manage the Moodle cluster](./Manage.md)
