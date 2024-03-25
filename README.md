
# Deploy and Manage a Scalable Moodle Cluster on Azure

This repository contains guides and [Azure Resource Manager](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-overview) templates designed to help you deploy and manage a highly available and scalable
[Moodle](https://moodle.com) cluster on Azure. In addition, the repository contains other useful information relevant to running Moodle on Azure such as a listing of Azure-relevant Moodle plugins and information on how to offer Moodle as a Managed Application on the Azure Marketplace or on an IT Service Catalog.

If you have an Azure account you can deploy Moodle via the [Azure portal](https://portal.azure.com) using the button below, or you can [deploy Moodle via the
CLI](docs/Deploy.md). Please note that while you can use an [Azure free account](https://azure.microsoft.com/en-us/free/) to get started depending on which template configuration you choose you will likely be required to upgrade to a paid account.

## Deployment Introduction

In the table below, we provide a number of default configurations at different scales of operation. These options minimize the configuration you would otherwise need to do manually; these options are essentially "good practice" recommendations. Once deployed, you will have full access to the Azure resources and can adjust the deployment to suit your needs. If you would prefer to have full control over all the configuration options at deployment, please refer to [the fully configurable section](#Fully Configurable) right after the Predefined deployment option section.

## SSH Key Requirement

All of the deployment options require you to provide a valid SSH protocol 2 (SSH-2) RSA public-private key pairs with a minimum length of 2048 bits. Other key formats such as ED25519 and ECDSA are not supported. 

If you are unfamiliar with SSH and SSH keys, read this [article](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys) which will explain how to generate a key pair.  You will create a ssh key pair. The public key is copied to the instances via the template. The private key is your identity that you will use to connect to different parts of the service.

## Predefined deployment options
Below are a list of pre-defined/restricted deployment options based on typical deployment scenarios (i.e. dev/test, production etc.) All configurations are fixed and you just need to pass your ssh public key to the template so that you can log in to the deployed VMs.

| Deployment Type | Description | Launch |
| --- | --- | ---
| Minimal  | This deployment will use NFS, Azure Database for MySQL Flexible Server (Burstable SKU 2 vCores), and smaller autoscale web frontend VM sku (1 core) that'll give faster deployment time (less than 30 minutes) and requires only 2 VM cores currently that'll fit even in a free trial Azure subscription.|[![Deploy to Azure Minimally](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FMoodle%2Fmaster%2Fazuredeploy-minimal.json)
| Small to Mid-Size | Supporting up to 1000 concurrent users.  This deployment will use NFS (no high availability) and Azure Database for MySQL Flexible Server(General Purpose SKU 8 vCores), without other options like elastic search or redis cache.|[![Deploy to Azure Minimally](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FMoodle%2Fmaster%2Fazuredeploy-small2mid-noha.json)
|Large size deployment (with high availability)| Supporting more than 2000 concurrent users. This deployment will use Gluster (for high availability, requiring 2 VMs), Azure Database for MySQL Flexible Server (General Purpose SKU 16 vCores) and redis cache, without other options like elastic search. |[![Deploy to Azure Minimally](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FMoodle%2Fmaster%2Fazuredeploy-large-ha.json)
| Maximum |This maximal deployment will use Gluster (for high availability, adding 2 VMs for a Gluster cluster), Azure Database for MySQL (Business Critical SKU 64 vCores), redis cache, elastic search (3 VMs), and pretty large storage sizes (both data disks and DB).|[![Deploy to Azure Maximally](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FMoodle%2Fmaster%2Fazuredeploy-maximal.json)

**NOTE**: The above deployment templates use hard coded Azure Database for MySQL Flexible Server SKUs for easier configuration and quicker deployment of Moodle workloads. If your deployment fails for any reason, please revert to the fully configurable template where possible and change the Azure Database for MySQL Flexible Server parameters accordingly.    

## Fully Configurable

If you would prefer to configure the deployment right at the start of the process, you use the button below. Please note that this method opens up a large number of parameters to configure and users new to this deployment process may find it overwhelming. It is also very likely you may end up with a deployment configuration that is not optimal to your needs. This method is recommended for power users.

[![Deploy to Azure Fully Configurable](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FMoodle%2Fmaster%2Fazuredeploy.json)  [![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.png)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FMoodle%2Fmaster%2Fazuredeploy.json)

**NOTE**: Before you deploy your Moodle workloads using a fully configurable template, we suggest reviewing [Azure Database for MySQL Flexible Server](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/) documentation to fully understand the parameters and the options suggested in the parameters to pick the right values for your workload needs.

## Stack Architecture

This template set deploys the following infrastructure core to your Moodle instance:
- Autoscaling web frontend layer (Nginx for https termination, Varnish for caching, Apache/php or nginx/php-fpm)
- Private virtual network for frontend instances
- Controller instance running cron and handling syslog for the autoscaled site
- [Azure Load balancer](https://azure.microsoft.com/en-us/services/load-balancer/) to balance across the autoscaled instances
- [Azure Database for MySQL](https://azure.microsoft.com/en-us/services/mysql/) or [Azure Database for PostgreSQL](https://azure.microsoft.com/en-us/services/postgresql/) or [Azure SQL Database](https://azure.microsoft.com/en-us/services/sql-database/)
- Dual [GlusterFS](https://www.gluster.org/) nodes or NFS for high availability access to Moodle files

This template set *optionally* configures the following additional infrastructure:
- [Azure Backup](https://azure.microsoft.com/en-us/services/backup/) for Moodle site backups
- [Azure Blob Storage](https://azure.microsoft.com/en-us/services/storage/blobs/) for ObjectFS (Moodle sitedata)
- [Azure Application Gateway](https://azure.microsoft.com/en-us/services/application-gateway/) for SSL offloading and WAF
- [Azure Redis Cache](https://azure.microsoft.com/en-us/services/cache/) instance for Moodle caching
- [Azure DDoS Protection](https://azure.microsoft.com/en-us/services/ddos-protection/) plan to secure your Moodle site from DDoS attacks
- [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/) for storing your CA Cert for your Moodle site
- [Azure Search](https://azure.microsoft.com/en-us/services/search/) instance or three Elasticsearch VMs for HA Global Search in Moodle
- [Apache Tika](http://tika.apache.org/) VMs for search indexing in Moodle

![network_diagram](images/stack_diagram.png "Diagram of deployed stack")

The template also optionally installs plugins that allow Moodle to be integrated with select Azure services (see below for details).

## Useful Moodle plugins for integrating Moodle with Azure Services
There below is a listing of useful plugins allow Moodle to be integrated with select Azure services:
- [Object File System Plugin*](https://github.com/catalyst/moodle-tool_objectfs) for [Azure Blob Storage](https://azure.microsoft.com/en-us/services/storage/blobs/)
- [Azure Search Plugin*](https://github.com/catalyst/moodle-search_azure) for [Azure Search](https://azure.microsoft.com/en-us/services/logic-apps/)
- [Trigger Plugin](https://github.com/catalyst/moodle-tool_trigger) and [Restful Webservice Plugin](https://github.com/catalyst/moodle-webservice_restful) for [Azure Logic Apps](https://azure.microsoft.com/en-us/services/logic-apps/) (requires use of [Moodle Connector](https://github.com/catalyst/azure-connector_moodle) now in development)
- [Office 365 and Microsoft Entra ID (formely Azure Active Directory) Plugins for Moodle*](https://github.com/Microsoft/o365-moodle) for [Microsoft Entra ID](https://www.microsoft.com/en-us/security/business/identity-access/microsoft-entra-id/)
- [Elasticsearch Plugin*](https://github.com/catalyst/moodle-search_elastic)

At the current time this template allows the optional installation of the plugins above with a * next to them. Please note these plugins can be installed at any time post deployment via Moodle's own [plugin directory](https://moodle.org/plugins/). You can find a list of all Azure relevant plugins in the Moodle plugin directory [here](https://moodle.org/plugins/browse.php?list=set&id=91). You might also choose to follow this list via RSS.

## Moodle as a Managed Application
You can learn more about how you can offer Moodle as a Managed Application on the Azure Marketplace or on an IT Service Catalog [here](https://github.com/Azure/Moodle/tree/master/managedApplication). This is a great read if you are offering Moodle hosting services today for your customers.

##  Observations about the current template
The template is highly configurable. Full details of the configuration options can be found in our [documentation](https://github.com/Azure/Moodle/tree/master/docs) (more specifically in our [parameters documentation](https://github.com/Azure/Moodle/blob/master/docs/Parameters.md)). The following sections describe observations about the template that you will likely want to review before deploying:

**Scalability** Our system is designed to be highly scalable. To achieve this we provide a Virtual Machine Scaleset for the web tier. This is already configured to scale on high load. However, scaling the VMs is not instantaneous. If you know you will have a high-load situation(e.g. exam, you should manually scale the VMs prior to the event. This can be done through the Azure portal or the CLI. The database is less easily scaled at this point, but it is possible and documented in our [management documentation](https://github.com/Azure/Moodle/blob/master/docs/Manage.md#resizing-your-database).

**SSL** The template fully supports SSL but it is not possible for the template to manage this for you. More information in our [managing certs documentation](https://github.com/Azure/Moodle/blob/master/docs/SslCert.md).

**Moodle PHP Code** The Moodle PHP code is stored on the Controller VM and copied to each front end VM upon deployment and upon request (should you update the Moodle code with your own code). For more information see our [management documentation](https://github.com/Azure/Moodle/blob/master/docs/Manage.md#updating-moodle-codesettings).

**Database** Currently the best performance is achieved with [Azure Database for MySQL](https://azure.microsoft.com/en-us/services/mysql/) and [Azure SQL Database](https://azure.microsoft.com/en-us/services/sql-database/). With [Azure Database for PostgreSQL](https://azure.microsoft.com/en-us/services/postgresql/) we have hit database constraints which caused processes to load up on the frontends until they ran out of memory. It is possible some PostgreSQL tuning might help here. Above pre-configured deployment templates deploy Azure Database for MySQL Flexible Server in a VNet. For configuring Azure Database for MySQL Flexible Server outside a VNet to use firewall-based IP restriction, please use the fully configurable template.

**File Storage** There are two options for file storage (moodledata) - Gluster FS and NFS. The Gluster FS solution is replicated thus provides highler availability, but incurs additional cost (2 x VMs) and some performance penalties (we are exploring ways to improve this and would welcome contributions from people who know Moodle and/or Gluster). NFS is highly performant and utilizes an existing VM in the cluster (so lower cost), but it is a single point of failure. At the time of writing there is no simple way to switch from one to the other depending on expected workloads and availability requirements, again this is something we would love to see resolved.

**Search.** Azure supports running an Elasticsearch cluster, however it does not offer a fully-managed Elasticsearch service, so for those looking for a fully-managed Search service [Azure Search](https://azure.microsoft.com/en-us/services/logic-apps/) is recommended.

**Caching.** While enabling Redis cache can improve performance for a large Moodle site we have not seen it be very effective for small-to-medium size sites. We can likely improve upon this, patches welcome ;-)

**Regions.** Note that not all resources types (such as databases) may be available in your region. You should check the list of [Azure Products by Region](https://azure.microsoft.com/en-us/global-infrastructure/services/) to for local availability.

## Common questions about this Template
1.  **Is this template Moodle as IaaS or PaaS?**  While the current template leverages PaaS services such as Redis, Azure Database for MySQL Flexible Server, Azure Database for Postgres, MS SQL etc. the current template offers Moodle as IaaS. Given limitations to Moodle our focus is IaaS for the time being however we would love to be informed of your experience running Moodle as PaaS on Azure (i.e. using [Azure Container Service](https://azure.microsoft.com/en-us/services/container-service/) or [Azure App Service](https://azure.microsoft.com/en-us/services/container-service/)).

2.  **The current template uses Ubuntu. Will other Operating Systems such as CentOS or Windows Server be supported in the future?** Unfortunately we only have plans to support Ubuntu at this time. It is highly unlikely that this will change.

3.  **What configuration do you recommend for my Moodle site?** The answer is it depends. At this stage we provide some rudimenatary t-shirt sized deployment recommendations and we are still building out our load testing tools and methodologies to provide more granularity. With that being said this is an area we are investing heavily in this area and we would love your contributions (i.e. load testing scripts, tools, methodologies etc.).

If you have an immediate need for guidance for a larger sized deployment, you might want to share some details around your deployment on our [issues page](https://github.com/Azure/Moodle/issues) and we will do our best to respond. Please share as much information about your deployment as possible such as:

  * average number of concurrent users your site will see
  * maximum level of concurrent/simultaenous users your site needs to support
  * whether or not HA is needed
  * any other attributes specific to your deployment (i.e. load balancing across regions etc.)

4. **Did Microsoft build this template alone or with the help of the Moodle community?** We did not build this template alone. We relied on the expertise and guidance of many capable Moodle partners around the world. The initial implementation of the template was done by [Catalyst IT](https://github.com/catalyst).

5. **How does this template relate to other Moodle offerings available on the Azure Marketplace?** It is generally not a good idea to run Moodle as a single VM in a production setting. This template is highly configurable and allows for high availability and redundancy.

6. **How does this template relate to this [Azure Quickstart Template for Moodle](https://github.com/Azure/azure-quickstart-templates/tree/master/application-workloads/moodle/moodle-scalable-cluster-ubuntu)?** This repo is the working repo for the quickstart template. We will be pushing changes from this template to the quickstart template on a regular cadence.

7. **I am already running Moodle on Azure. How does this work benefit me?** We are looking for painpoints from you and the broader Moodle on Azure community that we can help solve. We are also looking to understand where our implementation of Moodle on Azure outperforms or underperforms other implementations such as yours that are out in the wild. If you have observations, performance benchmarks or just general feedback about your experience running Moodle on Azure that you'd like to share we're extremely interested! Load testing is a very big area of focus, so if you have scripts you wouldn't mind contributing please let us know.

8.  **Has anyone run this template sucessfully in production?** Yes they have. With that being said, we do not make any performance guarantees about this architecture.

9.  **What type of improvements have you succeeded in making** Since we first began this effort we have managed to make great gains, achieving a >2x performance boost from our original configuration by making tweaks to things like where PHP files were stored. Our work is nowhere near over.  

10.  **What other Azure services (i.e. [Azure CDN](https://azure.microsoft.com/en-us/services/cdn/), [Azure Media Services](https://azure.microsoft.com/en-us/services/media-services/), [Azure Bot Service](https://azure.microsoft.com/en-us/services/bot-service/) etc.) will you be integrating with when this effort is complete?** It's not clear yet. We'll need your [feedback](https://github.com/Azure/Moodle/issues) to decide.

11.  **Why is the database on a public subnet?** At this stage only Azure Database for PostgreSQL do not support being moved to a vnet. As a workaround, we use a firewall-based IP restriction allow access only to the controller VM and VMSS load-balancer IPs.  

12. **Is Azure Database for MySQL Flexible Server deployed in a VNet?** When you leverage one of the pre-defined template options, we automatically deploy your Azure Database for MySQL Flexible Server in VNet for better isolation and greater security, optionally you can choose the fully configurable template to deploy Azure Database for MySQL Flexible Server outside VNet depending on your needs.

13.  **How can I help with this effort?** Please see below.

## Automated Testing (Travis CI)
This repository uses [Travis CI](https://travis-ci.org/) to deliver automated testing.

The following tests are carried out for every Pull Request and will also run in a Travis CI enabled forked repository:
* **JSON Linting** - All JSON files are linted to ensure they do not contain any syntax errors.
* **JSON Code Style** - All JSON files are tested to ensure they comply with project code style rules.

The following tests are carried out as part of the Pull Request merging prior to a contribution being accepted into the release branch:
* **Template Validation** - The template is subbmitted to Azure to ensure it is correclty formatted and contains valid logic.
* **Template Build** - The template is submitted to Azure and the stack described in the template is built to ensure a stack is correctly deployed.

### Setting Up Travis CI for Template Build
The following describes the process required if you want to run the template validation and build steps using your own Travis and Azure accounts.

To set up the build process, you will need:
* An Azure account or active subscription
* A fork of this repository linked to Travis CI
* Access to an installed instance of the Azure CLI
* A SSH keypair

The Travis CI process uses the *Azure CLI Service Principal* login method to authenticate against Azure. The documentation for logging in via a Service Principal can be found here: https://docs.microsoft.com/en-us/cli/azure/authenticate-azure-cli?view=azure-cli-latest#logging-in-with-a-service-principal

Before you can log in using the Service Principal process you need to create a *Service Principal*. The documentation to create a Service Principal login can be found here: https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?view=azure-cli-latest

When a Service Principal is created using the Azure CLI a JSON response is returned containing:
* **name** - This is the Service Principal username.
* **password** - This is the Service Principal password.
* **tenantId** - This is the Service Principal tenant unique ID.

You will need these three above values to have Travis and Azure deploy and test your template.

The next step is to take the above values returned by the Service Principal creation and use them to define *environment variables* in Travis CI.

The following link shows how to set up per repository environment variables in Travis CI: https://docs.travis-ci.com/user/environment-variables/#Defining-Variables-in-Repository-Settings Using this documention set up the following three *hidden* environment variables in Travis CI for your fork of this repository.

* **SPNAME** - The value of the *name* parameter returned by the Service Principal create proccess.
* **SPPASSWORD** - The value of the *password* parameter returned by the Service Principal create proccess.
* **SPTENANT** - The value of the *tenant* parameter returned by the Service Principal create proccess.
* **SPSSHKEY** *(default: generate new)*- A public SSH key that you have the corresponding private key for. This is currently not used but is required for the build to be successful.
* **LOCATION** *(default: southcentralus)*- Location for the test resource group.
* **RESOURCEGROUP** *(default: azmdl-travis-XXX)*- Name to use for the resource group.
* **FULLCI_BRANCHES** *(default: master)*- Name of branches (separated by ':') to always run FULL CI (if credentials are provided). Full CI will run a deployment test which will create and use resources from your Azure account.

**NOTE:** You can trigger a full CI test by adding *[full ci]* or *[fullci]* anywhere in the commit message.  

**NOTE:** Make sure you set the environment variables to hidden otherwise they will be exposed publically at run time.

**NOTE:** As per the Travis CI documentation make sure you have correctly escaped the enviroment variable values when they are defined.

Once the environment variables are defined, Travis CI will run the template validate and build steps as part of the test process.

## Contributing

This project welcomes contributions and suggestions. Our goal is to
work on Azure specific tooling for deploying and managing the open
source [Moodle](http://moodle.org) learning management system on
Azure. We do not work on Moodle itself here, instead we work upstream
as appropriate.

The short version of how to contribute to this project is "just do
it". Where "it" can be defined as any valuable contribution (and to be
clear, asking questions is a valuable contribution):

  * ask questions
  * provide feedback
  * write or update documentation
  * help new users
  * recommend the project to others
  * test the code and report bugs
  * fix bugs and issue pull requests
  * give us feedback on required features
  * write and update the software
  * create artwork
  * translate to different languages
  * anything you can see that needs doing

For a more detailed discussion of how to contribute see our [Contribution Guide](CONTRIBUTE.md).

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of
Conduct](https://opensource.microsoft.com/codeofconduct/). For more
information see the [Code of Conduct
FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact
[opencode@microsoft.com](mailto:opencode@microsoft.com) with any
additional questions or comments.

## Legal Notices

Microsoft and any contributors grant you a license to the Microsoft
documentation and other content in this repository under the [Creative
Commons Attribution 4.0 International Public
License](https://creativecommons.org/licenses/by/4.0/legalcode), see
the [LICENSE](LICENSE) file, and grant you a license to any code in
the repository under the [MIT
License](https://opensource.org/licenses/MIT), see the
[LICENSE-CODE](LICENSE-CODE) file.

Microsoft, Windows, Microsoft Azure and/or other Microsoft products
and services referenced in the documentation may be either trademarks
or registered trademarks of Microsoft in the United States and/or
other countries. The licenses for this project do not grant you rights
to use any Microsoft names, logos, or trademarks. Microsoft's general
trademark guidelines can be found at
http://go.microsoft.com/fwlink/?LinkID=254653.

Privacy information can be found at https://privacy.microsoft.com/en-us/

Microsoft and any contributors reserve all others rights, whether
under their respective copyrights, patents, or trademarks, whether by
implication, estoppel or otherwise.

## Next Steps

  1. [Deploy a Moodle Cluster](docs/Deploy.md)
  1. [Obtain Deployment Details about a Moodle Cluster](docs/Get-Install-Data.md)
  1. [Delete a Moodle Cluster](docs/Delete.md)
