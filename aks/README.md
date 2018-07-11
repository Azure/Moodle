# Using Azure Kubernetes Service (AKS) with the Azure/Moodle templates

[Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/) is now generally available (though it's available on select Azure regions. See [this](https://docs.microsoft.com/en-us/azure/aks/container-service-quotas#region-availability) for the exact/current region availability) with the [advanced networking support](https://docs.microsoft.com/en-us/azure/aks/networking-overview#advanced-networking) (that allows you to deploy a k8s cluster on an existing Azure subnet). With this general availability and the custom vnet support, we are happy to allow our Moodle templates users to choose an AKS cluster as a replacement of the current VMSS web frontend cluster. This document explains how to achieve that. Please note that this is still a proof-of-concept level implementation.

## Deploy the templates with AKS as the webClusterType parameter

Either using the Azure Portal or CLI (following [this documentation](../docs/README.md)), deploy the Moodle templates, but make sure to set the `webClusterType` parameter's value to `AKS`. In order to deploy the templates with AKS, you need to prepare and provide two more parameters: `aksServicePrincipalClientId` and `aksServicePrincipalClientSecret`. You can get these two parameters by creating an Azure service principal. Follow the instruction described [here](https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?view=azure-cli-latest#create-the-service-principal). The `appId` output value should be passed as `aksServicePrincipalClientId` and the `password` output value should be passed as `aksServicePrincipalClientSecret`. Read on to the subsection below before deploying the Moodle templates in order to set the role assignment, regardless of whether you are using CLI or Portal for deploying the templates.

Note that currently only `nfs` or `nfs-ha` are supported as the `fileServerType` parameter with `AKS` as the `webClusterType` option. We'll add support for other `fileServerType` options with `AKS` in the near future. Also the `mssql` option for the `dbServerType` parameter is not yet supported yet (it will deploy, but won't work), so please do make sure to choose either `mysql` or `postgres` (Note that we've experienced some perf issues with `postgres` when high load is applied. It was several months ago, so this issue might have been fixed by now, but we haven't confirmed it yet).

### Service principal role assignment required for AKS creation on a custom Azure vnet

Before deploying our Moodle templates with this generated service principal, you should also allow the service principal to control the Azure virtual network where the AKS cluster is to be created. This is achieved by creating a role assignment to the service principal on the scope of the Azure virtual network. You can use the Azure CLI command described [here](https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?view=azure-cli-latest#manage-service-principal-roles) to create a role assignment, but you should also specify a minimally valid `--scope ...` parameters for the needed virtual network only.

If you are bringing your own/existing Azure virtual network for the Moodle templates deployment, you can use the virtual network's Azure resource ID as the scope. If you are letting the Moodle templates to create a new virtual network for you, there's no virtual network Azure resource ID you can use at this stage, so your best bet is to specify the Azure resource ID of the resource group where you are deploying the Moodle templates. `Contributor` role is needed in either case.

In summary, if you are bringing an existing Azure virtual network for the Moodle templates deployment (that is, you are specifying the `Custom Vnet Id` template parameter), use the following command to create a role assignment for the service principal:

```
$ az role assignment create --assignee <app_id> --role Contributor --scope <custom_vnet_id>
```

If you are letting the Moodle templates create a new virtual network for your Moodle, use the following command to achieve the same:

```
$ az role assignment create --assignee <app_id> --role Contributor --scope /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/your_moodle_resource_group_name
```

Note that you must create your resource group (`your_moodle_resource_group_name`) before running this command (regardless of whether you use CLI or Portal for the Moodle templates deployment). Make sure to place the correct subscription ID and the resource group name in the above example. You should use the `your_moodle_resource_group_name` as the resource group for your Moodle templates deployment. Note that this is not ideal (because we are allowing the service principal to have wider scope than needed), and to avoid this, please consider creating your vnet separately, provide your vnet's Azure ID as the `Custom Vnet Id` template parameter and use it in the `--scope` parameter here as well.

If you have any difficulty with this step, do ask us for help by posting a GitHub issue. Please do make sure to paste your CLI commands and their outputs in your GitHub issue post.

## Start custom LAMP containers on the deployed AKS cluster

Deploying the templates for AKS creates various Azure resources (e.g., AKS VMs, Azure MySQL instance, controller VM, disks, ...) and installs Moodle on the controller VM. However, it won't start containers on AKS VMs, because k8s resources are not yet deployable through Azure Resource Manager. Therefore, containers on AKS VMs should be started separately on a command line. If you already used a Linux CLI to deploy the Moodle templates, it should be straightforward. If you used Azure Portal to deploy the Moodle templates, your best bet is to use [Azure Cloud Shell](https://shell.azure.com/) for this step. You can start the LAMP containers on the deployed AKS cluster by executing following commands on your choice of Linux CLI environment:

```
$ git clone https://github.com/Azure/Moodle/
$ cd Moodle
$ git checkout hs-aks
$ cd aks
$ ./deploy_azlamp_containers_on_aks.sh <your_moodle_resource_group>
```

Please do let us know if this step fails by posting your command execution results on our GitHub Issues. If this step succeeds, then you should be able to browse to the deployed site by entering `https://<siteURL>` in your browser. If you specified your own `siteURL` with your own domain, make sure to set up a CNAME record in your domain for the specified `siteURL` with the AKS load balancer public IP address DNS FQDN. It can be obtained by the following command:

```
$ az network public-ip list -g $(az aks list -g <your_moodle_resource_group> --query [].nodeResourceGroup -o tsv) --query [].dnsSettings.fqdn -o tsv
```

Again, if this step fails, please do let us know by posting your command execution results on the GitHub Issues.

# TODO

- Add support for Gluster `fileServerType`.
- Replace controller VM with a container: For non-HA NFS option, this requires using Azure Disk-backed k8s persistent volume and an NFS server container as described in this [example](https://github.com/kubernetes/examples/tree/master/staging/volumes/nfs). This option might not have been tested that much so we need some significant testing on this.
- The [custom LAMP container](https://hub.docker.com/r/hosungsmsft/azlamp/) is a very simple Apache PHP stack, whereas our original VMSS web frontend is with nginx (for https termination), varnish (for caching) and Apache/PHP. Without varnish caching, the AKS container option might have some performance penalty, so we'll need some perf study on those options and possibly add varnish to the [Dockerfile](images/azlamp/Dockerfile).