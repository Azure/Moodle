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
jq -r '.parameters | to_entries[] | "### " + .key + "\n\n" + .value.metadata.description + "\n\nType: " + .value.type + "\n\nPossible Values: " + (.value.allowedValues | @text) + "\n\nDefault: " + (.value.defaultValue | @text) + "\n\n"' azuredeploy.json
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


### autoscaleVmCount

Maximum number of autoscaled web VMs

Type: int

Possible Values: null

Default: 10


### autoscaleVmSku

VM size for autoscaled web VMs

Type: string

Possible Values: null

Default: Standard_DS2_v2


### azureBackupSwitch

Switch to configure AzureBackup and enlist VM's

Type: bool

Possible Values: null

Default: false


### controllerVmSku

VM size for the controller VM

Type: string

Possible Values: null

Default: Standard_DS1_v2


### dbLogin

Database admin username

Type: string

Possible Values: null

Default: dbadmin


### dbServerType

Database type

Type: string

Possible Values: ["postgres","mysql","mssql"]

Default: mysql


### elasticVmSku

VM size for the elastic search nodes

Type: string

Possible Values: null

Default: Standard_DS2_v2


### fileServerDiskCount

Number of disks in raid0 per gluster node or nfs server

Type: int

Possible Values: null

Default: 4


### fileServerDiskSize

Size per disk for gluster nodes or nfs server

Type: int

Possible Values: null

Default: 127


### fileServerType

File server type: GlusterFS, NFS--not yet highly available

Type: string

Possible Values: ["gluster","nfs"]

Default: nfs


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


### htmlLocalCopySwitch

Switch to create a local copy of /moodle/html or not

Type: bool

Possible Values: null

Default: false


### installElasticSearchSwitch

Switch to install Moodle ElasticSearch plugins & VMs

Type: bool

Possible Values: null

Default: false


### installO365pluginsSwitch

Switch to install Moodle Office 365 plugins

Type: bool

Possible Values: null

Default: false


### moodleVersion

The Moodle version you want to install.

Type: string

Possible Values: ["MOODLE_34_STABLE","MOODLE_33_STABLE","MOODLE_32_STABLE","MOODLE_31_STABLE","MOODLE_30_STABLE","MOODLE_29_STABLE"]

Default: MOODLE_34_STABLE


### mssqlDbEdition

MS SQL DB edition

Type: string

Possible Values: ["Basic","Standard"]

Default: Standard


### mssqlDbServiceObjectiveName

MS SQL database service object names

Type: string

Possible Values: ["S1","S2","S3","S4","S5","S6","S7","S9"]

Default: S1


### mssqlDbSize

MS SQL database size

Type: string

Possible Values: ["100MB","250MB","500MB","1GB","2GB","5GB","10GB","20GB","30GB","40GB","50GB","100GB","250GB","300GB","400GB","500GB","750GB","1024GB"]

Default: 250GB


### mssqlVersion

Mssql version

Type: string

Possible Values: ["12.0"]

Default: 12.0


### mysqlPgresSkuHwFamily

MySql/Postgresql sku hardware family

Type: string

Possible Values: ["Gen4","Gen5"]

Default: Gen4


### mysqlPgresSkuTier

MySql/Postgresql sku tier

Type: string

Possible Values: ["Basic","GeneralPurpose","MemoryOptimized"]

Default: GeneralPurpose


### mysqlPgresStgSizeGB

MySql/Postgresql storage size in GB. Minimum 5GB, increase by 1GB, up to 1TB (1024 GB)

Type: int

Possible Values: null

Default: 125


### mysqlPgresVcores

MySql/Postgresql vCores. For Basic tier, only 1 & 2 are allowed. For GeneralPurpose tier, 2, 4, 8, 16, 32 are allowed. For MemoryOptimized, 2, 4, 8, 16 are allowed.

Type: int

Possible Values: [1,2,4,8,16,32]

Default: 2


### mysqlVersion

Mysql version

Type: string

Possible Values: ["5.6","5.7"]

Default: 5.7


### postgresVersion

Postgresql version

Type: string

Possible Values: ["9.5","9.6"]

Default: 9.6


### redisDeploySwitch

Switch to deploy a redis cache or not

Type: bool

Possible Values: null

Default: true


### siteURL

URL for Moodle site

Type: string

Possible Values: null

Default: www.example.org


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


### storageAccountType

Storage Account type

Type: string

Possible Values: ["Standard_LRS","Standard_GRS","Standard_ZRS"]

Default: Standard_LRS


### vNetAddressSpace

Address range for the Moodle virtual network - presumed /16 - further subneting during vnet creation

Type: string

Possible Values: null

Default: 172.31.0.0


### vnetGwDeploySwitch

Switch to deploy a virtual network gateway or not

Type: bool

Possible Values: null

Default: false


### vpnType

Virtual network gateway vpn type

Type: string

Possible Values: ["RouteBased","PolicyBased"]

Default: RouteBased


### webServerType

Web server type

Type: string

Possible Values: ["apache","nginx"]

Default: apache


