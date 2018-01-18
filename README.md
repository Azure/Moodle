# Deploy and Manage a Scalable Moodle Cluster on Azure

This repo contains guides on how to deploy and manage a scalable
[Moodle](https://moodle.com) cluster on Azure. You can use an [Azure
free account](https://azure.microsoft.com/en-us/free/) to get started.

Once you have an Azure account you can deploy Moodle via the Azure
portal using the button below, or you can [deploy Moodle via the
CLI](docs/Deploy.md).

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FMoodle%2Fmaster%2Fmoodle-scalable-cluster-ubuntu%2Fazuredeploy.json)  [![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.png)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FMoodle%2Fmaster%2Fmoodle-scalable-cluster-ubuntu%2Fazuredeploy.json)

## What this stack will give you

This template set deploys the following infrastructure:
- Autoscaling web frontend layer (Nginx, php-fpm, Varnish)
- Private virtual network for frontend instances
- Controller instance running cron and handling syslog for the autoscaled site
- Load balancer to balance across the autoscaled instances
- Postgres or MySQL database
- Azure Redis instance for Moodle caching
- ObjectFS in Azure blobs (Moodle sitedata)
- Three Elasticsearch VMs for search indexing in Moodle
- Dual gluster nodes for high availability access to Moodle files

![network_diagram](images/stack_diagram.jpg "Diagram of deployed stack")

## Quickstart

Why not get started with [deploying a Moodle cluster on
Azure](docs/Deploy.md) right now.

## Contributing

This project welcomes contributions and suggestions. Most
contributions require you to agree to a Contributor License Agreement
(CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit
https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine
whether you need to provide a CLA and decorate the PR appropriately
(e.g., label, comment). Simply follow the instructions provided by the
bot. You will only need to do this once across all repos using our
CLA.

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

