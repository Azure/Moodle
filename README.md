# Deploy and Manage a Scalable Moodle Cluster on Azure

This repo contains guides on how to deploy and manage a scalable
[Moodle](https://moodle.com) cluster on Azure.

This document is designed to be "executed" by Simdem to produce an
interactive tutorial or a demo environment. However, it can also be
read as standard documentation.

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

## Configuration

We will use a number of environment variables to configure our
deployment. To customize them for your environment copy `env.json`
into `env.local.json` and edit the contents accordingly. The values
set within that file are:

``` shell
echo "Resource Group Name : $MOODLE_RG_NAME"
echo "Resource Group Location : $MOODLE_RG_LOCATION"
echo "Deployment Name : $MOODLE_DEPLOYMENT_NAME"
```

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

