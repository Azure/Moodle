# Moodle on Azure Parameters

Our goal with these templates is to make it as easy as possible to
deploy a Moodle on Azure cluster that can be customized to your
specific needs. To that end we provide a great manay configuration
options. This document attempts to document all these parameters,
however, like all documentation it can sometimes fall behind. For a
canonical reference you should review the `azuredeploy.json` file.

## Extracting documentation from azuredeploy.json

To make it a litte easier to read `azuredeploy.json` you might want to
run the following commands which will extract the necessary
information and display it in a more readable form.

```bash
sudp apt install jq
```

``` bash
jq -r '.parameters | to_entries[] | .key + "\n\t" + .value.metadata.description + "\n\tType: " + .value.type + "\n\tPossible Values: " + (.value.allowedValues | @text) + "\n\tDefault: " + (.value.defaultValue | @text) + "\n\n"' azuredeploy.json
```

## Available Parameters

### _artifactsLocation

The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.

Type: string
Possible Values: null
Default: https://raw.githubusercontent.com/Azure/Moodle/master/


### _artifactsLocationSasToken

The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated.

Type: securestring
Possible Values: null
Default:


### applyScriptsSwitch

Switch to process or bypass all scripts/extensions

Type: bool
Possible Values: null
Default: true


### azureBackupSwitch

Switch to configure AzureBackup and enlist VM's

Type: bool
Possible Values: null
Default: false


### redisDeploySwitch

Switch to deploy a redis cache or not

Type: bool
Possible Values: null
Default: true


### vnetGwDeploySwitch

Switch to deploy a virtual network gateway or not

Type: bool
Possible Values: null
Default: false


### installO365pluginsSwitch

Switch to install Moodle Office 365 plugins

Type: bool
Possible Values: null
Default: false


### installElasticSearchSwitch

Switch to install Moodle ElasticSearch plugins & VMs

Type: bool
Possible Values: null
Default: false


### storageAccountType

Storage Account type

Type: string
Possible Values: ["Standard_LRS","Standard_GRS","Standard_ZRS"]
Default: Standard_LRS


### dbServerType

Database type

Type: string
Possible Values: ["postgres","mysql","mssql"]
Default: mysql


### fileServerType

File server type: GlusterFS, Azure Files (CIFS)--disabled due to too slow perf, NFS--not highly available

Type: string
Possible Values: ["gluster","nfs"]
Default: gluster


### webServerType

Web server type

Type: string
Possible Values: ["apache","nginx"]
Default: apache


### controllerVmSku

VM size for the controller node

Type: string
Possible Values: null
Default: Standard_DS1_v2


### autoscaleVmSku

VM size for autoscaled nodes

Type: string
Possible Values: null
Default: Standard_DS2_v2


### autoscaleVmCount

Maximum number of autoscaled nodes

Type: int
Possible Values: null
Default: 10


### elasticVmSku

VM size for the elastic search nodes

Type: string
Possible Values: null
Default: Standard_DS2_v2


### firewallRuleName

Database firewall rule name

Type: string
Possible Values: null
Default: open-to-the-world


### gatewaySubnet

name for Virtual network gateway subnet

Type: string
Possible Values: ["GatewaySubnet"]
Default: GatewaySubnet


### gatewayType

Virtual network gateway type

Type: string
Possible Values: ["Vpn","ER"]
Default: Vpn


### glusterVmSku

VM size for the gluster nodes

Type: string
Possible Values: null
Default: Standard_DS2_v2


### fileServerDiskSize

Size per disk for gluster nodes or nfs server

Type: int
Possible Values: null
Default: 127


### fileServerDiskCount

Number of disks in raid0 per gluster node or nfs server

Type: int
Possible Values: null
Default: 4


### moodleVersion

The Moodle version you want to install.

Type: string
Possible Values: ["MOODLE_34_STABLE","MOODLE_33_STABLE","MOODLE_32_STABLE","MOODLE_31_STABLE","MOODLE_30_STABLE","MOODLE_29_STABLE"]
Default: MOODLE_34_STABLE


### dbLogin

Database admin username

Type: string
Possible Values: null
Default: dbadmin


### siteURL

URL for Moodle site

Type: string
Possible Values: null
Default: www.example.org


### skuCapacityDTU

MySql/Postgresql database trasaction units

Type: int
Possible Values: [50,100,200,400,800]
Default: 100


### serviceObjective

MS SQL  database trasaction units

Type: string
Possible Values: ["S1","S2","S3","S4","S5","S6","S7","S9"]
Default: S1


### msDbSize

MS SQL database size

Type: string
Possible Values: ["100MB","250MB","500MB","1GB","2GB","5GB","10GB","20GB","30GB","40GB","50GB","100GB","250GB","300GB","400GB","500GB","750GB","1024GB"]
Default: 250GB


### skuFamily

MySql/Postgresql sku family

Type: string
Possible Values: ["SkuFamily"]
Default: SkuFamily


### skuName

MySql/Postgresql sku name

Type: string
Possible Values: ["PGSQLB50","PGSQLB100","PGSQLS100","PGSQLS200","PGSQLS400","PGSQLS800","MYSQLB50","MYSQLB100","MYSQLS100","MYSQLS200","MYSQLS400","MYSQLS800"]
Default: MYSQLS100


### skuSizeMB

MySql/Postgresql sku size in MB. For Basic tier, minimum 50GB, increased by 125GB up to 1TB. For Standard tier, minimum 125GB, increase by 125GB up to 1TB

Type: int
Possible Values: null
Default: 128000


### skuTier

MySql/Postgresql sku tier

Type: string
Possible Values: ["Basic","Standard"]
Default: Standard


### sshPublicKey

ssh public key

Type: string
Possible Values: null
Default: null


### sshUsername

ssh user name

Type: string
Possible Values: null
Default: azureadmin


### sslEnforcement

MySql/Postgresql SSL connection

Type: string
Possible Values: ["Disabled","Enabled"]
Default: Disabled


### postgresVersion

Postgresql version

Type: string
Possible Values: ["9.5","9.6"]
Default: 9.6


### mysqlVersion

Mysql version

Type: string
Possible Values: ["5.6","5.7"]
Default: 5.7


### mssqlVersion

Mssql version

Type: string
Possible Values: ["12.0"]
Default: 12.0


### vNetAddressSpace

Address range for the Moodle virtual network - presumed /16 - further subneting during vnet creation

Type: string
Possible Values: null
Default: 172.31.0.0


### vpnType

Virtual network gateway vpn type

Type: string
Possible Values: ["RouteBased","PolicyBased"]
Default: RouteBased



