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
sudo apt install jq
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


### azureBackupSwitch

Switch to configure AzureBackup and enlist VM's

Type: bool

Possible Values: null

Default: false


### redisDeploySwitch

Switch to deploy a redis cache or not. Note that certain versions of Moodle (e.g., 3.1) don't work well with Redis, so use this only for known well-working Moodle versions (e.g., 3.4).

Type: bool

Possible Values: null

Default: false


### vnetGwDeploySwitch

Switch to deploy a virtual network gateway or not

Type: bool

Possible Values: null

Default: false


### installObjectFsSwitch

Switch to install Moodle Object FS plugins (with Azure Blob storage)

Type: bool

Possible Values: null

Default: false


### installO365pluginsSwitch

Switch to install Moodle Office 365 plugins. As of May 22, 2018, O365 plugins for Moodle 3.5 haven't been released, so to set this true, you must set the moodleVersion to 3.4 or below.

Type: bool

Possible Values: null

Default: false


### installGdprPluginsSwitch

(Should be used only for Moodle 3.4 & 3.3) Switch to install Moodle GDPR plugins. Note these require Moodle versions 3.4.2+ or 3.3.5+ and these are included by default in Moodle 3.5. So if you choose MOODLE_35_STABLE as your moodleVersion, do not set this to true.

Type: bool

Possible Values: null

Default: false


### htmlLocalCopySwitch

Switch to create a local copy of /moodle/html or not

Type: bool

Possible Values: null

Default: true


### ddosSwitch

Switch to create a DDoS protection plan

Type: bool

Possible Values: null

Default: false


### enableAccelNwForCtlrVmSwitch

Switch to enable Azure Accelerated Networking on the controller VM. Required by the default Ddsv5 VM size; keep enabled unless selecting a different compatible VM family.

Type: bool

Possible Values: null

Default: true


### enableAccelNwForOtherVmsSwitch

Switch to enable Azure Accelerated Networking on all other VMs. Required by the default Ddsv5 VM sizes; keep enabled unless selecting a different compatible VM family.

Type: bool

Possible Values: null

Default: true


### vnetDbDeploySwitch

Switch to deploying the db in VNet. Note: currently the Vnet DB Deployment is available for mysqlflex only. For other db server types, the database will not be deployed in VNet.

Type: bool

Possible Values: null

Default: false


### httpsTermination

Indicates where https termination occurs. 'VMSS' is for https termination at the VMSS instance VMs (using nginx https proxy). 'AppGw' is for https termination with an Azure Application Gateway. When selecting this, you need to specify all appGw* parameters. 'None' is for testing only with no https. 'None' may not be used with a separately configured https termination layer. If you want to use the 'None' option with your separately configured https termination layer, you'll need to update your Moodle config.php manually for $cfg->wwwroot and $cfg->sslproxy.

Type: string

Possible Values: ["VMSS","AppGw","None"]

Default: VMSS


### siteURL

URL for Moodle site

Type: string

Possible Values: null

Default: www.example.org


### moodleVersion

The Moodle version you want to install.

Type: string

Possible Values: ["MOODLE_503_STABLE"]

Default: MOODLE_503_STABLE


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


### controllerVmSku

VM size for the controller VM

Type: string

Possible Values: null

Default: Standard_D4ds_v5


### webServerType

Web server type

Type: string

Possible Values: ["apache","nginx"]

Default: nginx


### autoscaleVmSku

VM size for autoscaled web VMs

Type: string

Possible Values: null

Default: Standard_D2ds_v5


### autoscaleVmCountMax

Maximum number of autoscaled web VMs

Type: int

Possible Values: null

Default: 10


### autoscaleVmCountMin

Minimum (also initial) number of autoscaled web VMs

Type: int

Possible Values: null

Default: 1


### osDiskStorageType

Azure storage type for all VMs' OS disks. With htmlLocalCopySwith true, Premium_LRS (SSD) is strongly recommended, as PHP files will be served from OS disks.

Type: string

Possible Values: ["Premium_LRS","Standard_LRS"]

Default: Premium_LRS


### phpVersion

php version

Type: string

Possible Values: ["8.3"]

Default: 8.3


### dbServerType

Database type

Type: string

Possible Values: ["postgres","mssql","mysqlflex"]

Default: mysqlflex


### dbLogin

Database admin username

Type: string

Possible Values: null

Default: dbadmin


### moodleDbName

Moodle Database name

Type: string

Possible Values: null

Default: moodle


### moodleDbUser

Moodle Database username. This user is different from Database admin user.

Type: string

Possible Values: null

Default: moodle


### mysqlflexVersion

MySQL Flexible Server version for new Moodle 5.3 deployments. Uses API 2025-06-01-preview for MySQL 8.4; existing databases require a separate backed-up upgrade and cutover plan.

Type: string

Possible Values: ["8.4"]

Default: 8.4


### mysqlflexSkuName

The name of the sku for Azure Database for MySQL Flexible Servers, e.g. Standard_D32ds_v4. Complete list is available here : https://learn.microsoft.com/en-us/azure/mysql/flexible-server/concepts-service-tiers-storage

Type: string

Possible Values: ["Standard_B1s","Standard_B1ms","Standard_B2s","Standard_B2ms","Standard_B4ms","Standard_B8ms","Standard_B12ms","Standard_B16ms","Standard_B20ms","Standard_D2ads_v5","Standard_D2ds_v4","Standard_D4ads_v5","Standard_D4ds_v4","Standard_D8ads_v5","Standard_D8ds_v4","Standard_D16ads_v5","Standard_D16ds_v4","Standard_D32ads_v5","Standard_D32ds_v4","Standard_D48ads_v5","Standard_D48ds_v4","Standard_D64ads_v5","Standard_D64ds_v4","Standard_E2ds_v4","Standard_E2ads_v5","Standard_E4ds_v4","Standard_E4ads_v5","Standard_E8ds_v4","Standard_E8ads_v5","Standard_E16ds_v4","Standard_E16ads_v5","Standard_E32ds_v4","Standard_E32ads_v5","Standard_E48ds_v4","Standard_E48ads_v5","Standard_E64ds_v4","Standard_E64ads_v5","Standard_E80ids_v4","Standard_E2ds_v5","Standard_E4ds_v5","Standard_E8ds_v5","Standard_E16ds_v5","Standard_E32ds_v5","Standard_E48ds_v5","Standard_E64ds_v5","Standard_E96ds_v5"]

Default: Standard_B2s


### mysqlflexStgSizeGiB

Azure Database for MySQL Flexible server storage size in GiB. Minimum 20GiB, increase by 1GiB, up to 16TiB (1024 GiB)

Type: int

Possible Values: null

Default: 20


### mysqlflexStgIops

Azure Database for MySQL Flexible server storage iops. Minimum 360, Maxium is determined by selected mysqlflexSkuName.

Type: int

Possible Values: null

Default: 360


### mysqlflexStgAutogrow



Type: string

Possible Values: ["Enabled","Disabled"]

Default: Enabled


### mysqlflexHaEnabled

High availability mode for azure database for mysql flexible server.

Type: string

Possible Values: ["Disabled","SameZone","ZoneRedundant"]

Default: Disabled


### mysqlflexAvailabilityZone

Availability Zone information of the server. (Leave blank for No Preference).

Type: string

Possible Values: ["1","2","3",""]

Default:


### mysqlflexStandbyAvailabilityZone

Availability zone of the High availability standby server. (Leave blank for No Preference). Add this value if HA is enabled.

Type: string

Possible Values: ["1","2","3",""]

Default:


### postgresVersion

PostgreSQL Flexible Server major version for new deployments. Existing databases require a separately rehearsed migration and rollback plan.

Type: string

Possible Values: ["18"]

Default: 18


### postgresSkuName

PostgreSQL Flexible Server compute size; verify regional availability and tier compatibility.

Type: string

Possible Values: null

Default: Standard_D2ds_v5


### postgresSkuTier

PostgreSQL Flexible Server compute tier matching postgresSkuName.

Type: string

Possible Values: ["Burstable","GeneralPurpose","MemoryOptimized"]

Default: GeneralPurpose


### postgresStorageSizeGiB

PostgreSQL Flexible Server Premium SSD storage size in GiB.

Type: int

Possible Values: null

Default: 128


### sslEnforcement

MySql/Postgresql SSL connection

Type: string

Possible Values: ["Disabled","Enabled"]

Default: Disabled


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


### mssqlDbEdition

MS SQL DB edition

Type: string

Possible Values: ["Basic","Standard"]

Default: Standard


### mssqlVersion

Mssql version

Type: string

Possible Values: ["12.0"]

Default: 12.0


### fileServerType

Shared file service: NFS, NFS-HA, BYO NFS or Azure Files. Gluster is no longer supported.

Type: string

Possible Values: ["nfs","nfs-ha","nfs-byo","azurefiles"]

Default: nfs


### nfsByoIpExportPath

IP address and export path of the BYO-NFS share when fileServerType == nfs-byo. E.g., 172.16.1.8:/msazure

Type: string

Possible Values: null

Default:


### OSDiskSizeInGB

OS disk size per Webserver in VMSS

Type: int

Possible Values: null

Default: 256


### fileServerDiskSize

Size in GiB per NFS data disk

Type: int

Possible Values: null

Default: 127


### fileServerDiskCount

Number of data disks for the NFS server

Type: int

Possible Values: null

Default: 4


### fileServerVmSku

VM size for the NFS-HA nodes

Type: string

Possible Values: null

Default: Standard_D4ds_v5


### keyVaultResourceId

(VMSS https termination only) Azure Resource Manager resource ID of the Key Vault in case you stored your SSL cert in an Azure Key Vault (Note that this Key Vault must have been pre-created on the same Azure region where this template is being deployed). Leave this blank if you didn't. Resource ID example: /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/xxx/providers/Microsoft.KeyVault/vaults/yyy. This value can be obtained from keyvault.sh output if you used the script to store your SSL cert in your Key Vault.

Type: string

Possible Values: null

Default: 


### sslCertKeyVaultURL

(VMSS https termination only) Azure Key Vault URL for your stored SSL cert. This value can be obtained from keyvault.sh output if you used the script to store your SSL cert in your Key Vault. This parameter is ignored if the keyVaultResourceId parameter is blank.

Type: string

Possible Values: null

Default: 


### sslCertThumbprint

(VMSS https termination only) Thumbprint of your stored SSL cert. This value can be obtained from keyvault.sh output if you used the script to store your SSL cert in your Key Vault. This parameter is ignored if the keyVaultResourceId parameter is blank.

Type: string

Possible Values: null

Default: 


### caCertKeyVaultURL

(VMSS https termination only) Azure Key Vault URL for your stored CA (Certificate Authority) cert. This value can be obtained from keyvault.sh output if you used the script to store your CA cert in your Key Vault. This parameter is ignored if the keyVaultResourceId parameter is blank.

Type: string

Possible Values: null

Default: 


### caCertThumbprint

(VMSS https termination only) Thumbprint of your stored CA cert. This value can be obtained from keyvault.sh output if you used the script to store your CA cert in your Key Vault. This parameter is ignored if the keyVaultResourceId parameter is blank.

Type: string

Possible Values: null

Default: 


### appGwSslCertKeyVaultResourceId

(App Gateway https termination only) Azure Key Vault URL for your stored SSL cert, again for App Gateway https termination case only. (Note that this Key Vault must have been pre-created on the same Azure region where this template is being deployed). Leave this blank if you didn't. Resource ID example: /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/xxx/providers/Microsoft.KeyVault/vaults/yyy.

Type: string

Possible Values: null

Default: 


### appGwSslCertKeyVaultSecretName

(App Gateway https termination only) Name of the Azure Key Vault secret that's stored in the previously specified Key Vault as a PFX certificate (with no password) for your site's SSL cert. This secret must be pre-populated in the specified Key Vault with the matching name.

Type: string

Possible Values: null

Default: 


### appGwWebSubnetEgressPublicIp

(App Gateway with a custom VNet only) Static public egress IP used by the web subnet. Required when the custom web subnet uses public database access; ignored for repository-created VNets, which deploy a NAT Gateway.

Type: string

Possible Values: null

Default:


### appGwSkuName

(App Gateway https termination only) Name of the Applicate Gateway SKU

Type: string

Possible Values: ["Standard_v2","WAF_v2"]

Default: Standard_v2


### appGwSkuTier

(App Gateway https termination only) Tier of the Applicate Gateway

Type: string

Possible Values: ["Standard_v2","WAF_v2"]

Default: Standard_v2


### appGwSkuCapacity

(App Gateway https termination only) Capacity instance count) of the Applicate Gateway

Type: int

Possible Values: null

Default: 2


### storageAccountType

Storage account replication and performance. Premium_LRS creates BlockBlobStorage for ObjectFS or FileStorage for Azure Files; standard SKUs create StorageV2.

Type: string

Possible Values: ["Standard_LRS","Standard_GRS","Standard_ZRS","Premium_LRS"]

Default: Standard_LRS


### searchType

options of moodle global search

Type: string

Possible Values: ["none","azure","elastic"]

Default: none


### azureSearchSku

the search service level you want to create.

Type: string

Possible Values: ["free","basic","standard","standard2","standard3"]

Default: basic


### azureSearchReplicaCount

Replicas distribute search workloads across the service. You need 2 or more to support high availability (applies to Basic and Standard only).

Type: int

Possible Values: null

Default: 3


### azureSearchPartitionCount

Partitions allow for scaling of document count as well as faster indexing by sharding your index over multiple Azure Search units.

Type: int

Possible Values: [1,2,3,4,6,12]

Default: 1


### azureSearchHostingMode

Applicable only for azureSearchSku set to standard3. You can set this property to enable a single, high density partition that allows up to 1000 indexes, which is much higher than the maximum indexes allowed for any other azureSearchSku.

Type: string

Possible Values: ["default","highDensity"]

Default: default


### elasticVmSku

VM size for the elastic search nodes

Type: string

Possible Values: null

Default: Standard_D2ds_v5


### customVnetId

Azure Resource ID of the Azure virtual network where you want to deploy your Moodle resources. A vnet resource ID is of the following format: /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxxxxxx/resourceGroups/gggg/providers/Microsoft.Network/virtualNetworks/vvvv. Note that this virtual network must be on the same Azure location as this template deployment location. If this parameter is blank, a new Azure virtual network will be created and used. In that case, the address space of the newly created virtual network will be */16 of the following vNetAddressSpace parameter value below.

Type: string

Possible Values: null

Default: 


### vNetAddressSpace

Address range for the Moodle virtual network and various subnets - presumed /16 for a newly created vnet in case customVnetId is blank. Further subneting (a number of */24 subnets starting from the xxx.yyy.zzz.0/24 will be created on a newly created vnet or your BYO-vnet (specified in customVnetId parameter).

Type: string

Possible Values: null

Default: 172.31.0.0


### gatewayType

Virtual network gateway type

Type: string

Possible Values: ["Vpn","ER"]

Default: Vpn


### vpnType

Virtual network gateway vpn type

Type: string

Possible Values: ["RouteBased","PolicyBased"]

Default: RouteBased


### loadBalancerSku

Loadbalancer SKU

Type: string

Possible Values: ["Standard"]

Default: Standard


### loadBalancerTier

Loadbalancer Tier

Type: string

Possible Values: ["Regional","Global"]

Default: Regional


### ubuntuVersion



Type: string

Possible Values: ["24_04-lts-gen2"]

Default: 24_04-lts-gen2


### location

Azure Location for all resources.

Type: string

Possible Values: null

Default: [resourceGroup().location]


### isMigration

Indicates whether the this template is using for migration scenario.

Type: bool

Possible Values: null

Default: false
