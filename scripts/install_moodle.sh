#!/bin/bash

# The MIT License (MIT)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -ex

#parameters 
{
    moodle_on_azure_configs_json_path=${1}

    . ./helper_functions.sh

    get_setup_params_from_configs_json $moodle_on_azure_configs_json_path || exit 99

    echo moodleVersion $moodleVersion        >> /tmp/vars.txt
    echo glusterNode $glusterNode          >> /tmp/vars.txt
    echo glusterVolume $glusterVolume        >> /tmp/vars.txt
    echo siteFQDN $siteFQDN             >> /tmp/vars.txt
    echo httpsTermination $httpsTermination     >> /tmp/vars.txt
    echo dbIP $dbIP                 >> /tmp/vars.txt
    echo moodledbname $moodledbname         >> /tmp/vars.txt
    echo moodledbuser $moodledbuser         >> /tmp/vars.txt
    echo moodledbpass $moodledbpass         >> /tmp/vars.txt
    echo adminpass $adminpass            >> /tmp/vars.txt
    echo dbadminlogin $dbadminlogin         >> /tmp/vars.txt
    echo dbadminloginazure $dbadminloginazure    >> /tmp/vars.txt
    echo dbadminpass $dbadminpass          >> /tmp/vars.txt
    echo storageAccountName $storageAccountName   >> /tmp/vars.txt
    echo storageAccountKey $storageAccountKey    >> /tmp/vars.txt
    echo azuremoodledbuser $azuremoodledbuser    >> /tmp/vars.txt
    echo redisDns $redisDns             >> /tmp/vars.txt
    echo redisAuth $redisAuth            >> /tmp/vars.txt
    echo elasticVm1IP $elasticVm1IP         >> /tmp/vars.txt
    echo installO365pluginsSwitch $installO365pluginsSwitch    >> /tmp/vars.txt
    echo dbServerType $dbServerType                >> /tmp/vars.txt
    echo fileServerType $fileServerType              >> /tmp/vars.txt
    echo mssqlDbServiceObjectiveName $mssqlDbServiceObjectiveName >> /tmp/vars.txt
    echo mssqlDbEdition $mssqlDbEdition	>> /tmp/vars.txt
    echo mssqlDbSize $mssqlDbSize	>> /tmp/vars.txt
    echo installObjectFsSwitch $installObjectFsSwitch >> /tmp/vars.txt
    echo installGdprPluginsSwitch $installGdprPluginsSwitch >> /tmp/vars.txt
    echo thumbprintSslCert $thumbprintSslCert >> /tmp/vars.txt
    echo thumbprintCaCert $thumbprintCaCert >> /tmp/vars.txt
    echo searchType $searchType >> /tmp/vars.txt
    echo azureSearchKey $azureSearchKey >> /tmp/vars.txt
    echo azureSearchNameHost $azureSearchNameHost >> /tmp/vars.txt
    echo tikaVmIP $tikaVmIP >> /tmp/vars.txt
    echo nfsByoIpExportPath $nfsByoIpExportPath >> /tmp/vars.txt
    echo storageAccountType $storageAccountType >>/tmp/vars.txt
    echo fileServerDiskSize $fileServerDiskSize >>/tmp/vars.txt
    echo phpVersion $phpVersion         >> /tmp/vars.txt
    echo moodleStackConfigurationDownloadPath $moodleStackConfigurationDownloadPath >> /tmp/vars.txt
    echo confLocation $confLocation >> /tmp/vars.txt
    echo artifactsSasToken $artifactsSasToken >> /tmp/vars.txt

    check_fileServerType_param $fileServerType

    #Updating php sources
   sudo add-apt-repository ppa:ondrej/php -y
   sudo apt-get update

    if [ "$dbServerType" = "mysql" ]; then
      mysqlIP=$dbIP
      mysqladminlogin=$dbadminloginazure
      mysqladminpass=$dbadminpass
    elif [ "$dbServerType" = "mssql" ]; then
      mssqlIP=$dbIP
      mssqladminlogin=$dbadminloginazure
      mssqladminpass=$dbadminpass

    elif [ "$dbServerType" = "postgres" ]; then
      postgresIP=$dbIP
      pgadminlogin=$dbadminloginazure
      pgadminpass=$dbadminpass
    else
      echo "Invalid dbServerType ($dbServerType) given. Only 'mysql' or 'postgres' or 'mssql' is allowed. Exiting"
      exit 1
    fi

    # make sure system does automatic updates and fail2ban
    sudo apt-get -y update
    sudo apt-get -y install unattended-upgrades fail2ban

    config_fail2ban
    
    #Create directory for conf files to download
    mkdir -p $moodleStackConfigurationDownloadPath

    # Download moodle.vcl
    moodleVclUrl="${confLocation}moodle.vcl${artifactsSasToken}"
    wget ${moodleVclUrl} -O "${moodleStackConfigurationDownloadPath}/moodle.vcl"

    # Download nginx.conf
    if [ "$httpsTermination" = "None" ]; then 
      nginxConfFileName="nginx_and_none_nginx.conf"
    else 
      nginxConfFileName="nginx_and_VMSS_nginx.conf"
    fi

    nginxConfUri="${confLocation}${nginxConfFileName}${artifactsSasToken}"
    wget ${nginxConfUri} -O "${moodleStackConfigurationDownloadPath}/nginx.conf"

    # Download siteFQDN.conf
    if [ "$httpsTermination" = "VMSS" ]; then
      siteFqdnFileName="sitefqdn_vmss_and_nginx.conf"
    elif [ "$httpsTermination" = "None" ]; then
      siteFqdnFileName="sitefqdn_none_and_nginx.conf"
    else
      siteFqdnFileName="sitefqdn_appgw_and_nginx.conf"
    fi

    siteFqdnUri="${confLocation}${siteFqdnFileName}${artifactsSasToken}"
    wget ${siteFqdnUri} -O "${moodleStackConfigurationDownloadPath}/siteFqdn.conf"

    # Find and replace htmlRootDir based on condition
    if [ "$htmlLocalCopySwitch" = "true" ]; then
        rootDir="/var/www/html/moodle"
    else
        rootDir="/moodle/html/moodle"
    fi

    # Replace root directory
    sudo sed -i "s~\${htmlRootDir}~$rootDir~" ${moodleStackConfigurationDownloadPath}/siteFqdn.conf


    # create gluster, nfs or Azure Files mount point
    mkdir -p /moodle

    export DEBIAN_FRONTEND=noninteractive

    if [ $fileServerType = "gluster" ]; then
        # configure gluster repository & install gluster client
        sudo add-apt-repository ppa:gluster/glusterfs-3.10 -y                 >> /tmp/apt1.log
    elif [ $fileServerType = "nfs" ]; then
        # configure NFS server and export
        setup_raid_disk_and_filesystem /moodle /dev/md1 /dev/md1p1
        configure_nfs_server_and_export /moodle
    fi

    sudo apt-get -y update                                                   >> /tmp/apt2.log
    sudo apt-get -y --force-yes install rsyslog git                          >> /tmp/apt3.log

    if [ $fileServerType = "gluster" ]; then
        sudo apt-get -y --force-yes install glusterfs-client                 >> /tmp/apt3.log
    elif [ "$fileServerType" = "azurefiles" ]; then
        sudo apt-get -y --force-yes install cifs-utils                       >> /tmp/apt3.log
    fi

    if [ $dbServerType = "mysql" ]; then
        sudo apt-get -y --force-yes install mysql-client >> /tmp/apt3.log
    elif [ "$dbServerType" = "postgres" ]; then
        sudo apt-get -y --force-yes install postgresql-client >> /tmp/apt3.log
    fi
	
    if [ "$installObjectFsSwitch" = "true" -o "$fileServerType" = "azurefiles" ]; then
	# install azure cli & setup container
        echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
            sudo tee /etc/apt/sources.list.d/azure-cli.list
        curl -L https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add - >> /tmp/apt4.log
        sudo apt-get -y install apt-transport-https >> /tmp/apt4.log
        sudo apt-get -y update > /dev/null
        sudo apt-get -y install azure-cli >> /tmp/apt4.log
	
        # FileStorage accounts can only be used to store Azure file shares;
        # Premium_LRS will support FileStorage kind
        # No other storage resources (blob containers, queues, tables, etc.) can be deployed in a FileStorage account.
        if [ $storageAccountType != "Premium_LRS" ]; then
		az storage container create \
		    --name objectfs \
		    --account-name $storageAccountName \
		    --account-key $storageAccountKey \
		    --public-access off \
		    --fail-on-exist >> /tmp/wabs.log

		az storage container policy create \
		    --account-name $storageAccountName \
		    --account-key $storageAccountKey \
		    --container-name objectfs \
		    --name readwrite \
		    --start $(date --date="1 day ago" +%F) \
		    --expiry $(date --date="2199-01-01" +%F) \
		    --permissions rw >> /tmp/wabs.log

		sas=$(az storage container generate-sas \
		    --account-name $storageAccountName \
		    --account-key $storageAccountKey \
		    --name objectfs \
		    --policy readwrite \
		    --output tsv)
	fi
    fi

    if [ $fileServerType = "gluster" ]; then
        # mount gluster files system
        echo -e '\n\rInstalling GlusterFS on '$glusterNode':/'$glusterVolume '/moodle\n\r' 
        setup_and_mount_gluster_moodle_share $glusterNode $glusterVolume
    elif [ $fileServerType = "nfs-ha" ]; then
        # mount NFS-HA export
        echo -e '\n\rMounting NFS export from '$nfsHaLbIP' on /moodle\n\r'
        configure_nfs_client_and_mount $nfsHaLbIP $nfsHaExportPath /moodle
    elif [ $fileServerType = "nfs-byo" ]; then
        # mount NFS-BYO export
        echo -e '\n\rMounting NFS export from '$nfsByoIpExportPath' on /moodle\n\r'
        configure_nfs_client_and_mount0 $nfsByoIpExportPath /moodle
    fi
    
    # install pre-requisites
    sudo add-apt-repository ppa:ubuntu-toolchain-r/ppa
    sudo apt-get -y update > /dev/null 2>&1
    sudo apt-get install -y --fix-missing python-software-properties unzip
    #sudo apt-get install software-properties-common
    #sudo apt-get install unzip


    # install the entire stack
    # passing php versions $phpVersion
    sudo apt-get -y  --force-yes install nginx php$phpVersion-fpm varnish >> /tmp/apt5a.log
    sudo apt-get -y  --force-yes install php$phpVersion php$phpVersion-cli php$phpVersion-curl php$phpVersion-zip >> /tmp/apt5b.log

    # Moodle requirements
    sudo apt-get -y update > /dev/null
    sudo apt-get install -y --force-yes graphviz aspell php$phpVersion-common php$phpVersion-soap php$phpVersion-json php$phpVersion-redis > /tmp/apt6.log
    sudo apt-get install -y --force-yes php$phpVersion-bcmath php$phpVersion-gd php$phpVersion-xmlrpc php$phpVersion-intl php$phpVersion-xml php$phpVersion-bz2 php-pear php$phpVersion-mbstring php$phpVersion-dev mcrypt >> /tmp/apt6.log
    PhpVer=$(get_php_version)
    if [ $dbServerType = "mysql" ]; then
        sudo apt-get install -y --force-yes php$phpVersion-mysql
    elif [ $dbServerType = "mssql" ]; then
        sudo apt-get install -y libapache2-mod-php  # Need this because install_php_mssql_driver tries to update apache2-mod-php settings always (which will fail without this)
        install_php_mssql_driver
    else
        sudo apt-get install -y --force-yes php-pgsql
    fi

    # Set up initial moodle dirs
    mkdir -p /moodle/html
    mkdir -p /moodle/certs
    mkdir -p /moodle/moodledata

    o365pluginVersion=$(get_o365plugin_version_from_moodle_version $moodleVersion)
    moodleStableVersion=$o365pluginVersion  # Need Moodle stable version for GDPR plugins, and o365pluginVersion is just Moodle stable version, so reuse it.
    moodleUnzipDir=$(get_moodle_unzip_dir_from_moodle_version $moodleVersion)

    # install Moodle 
    echo '#!/bin/bash
    mkdir -p /moodle/tmp
    cd /moodle/tmp

    if [ ! -d /moodle/html/moodle ]; then
        # downloading moodle only if /moodle/html/moodle does not exist -- if it exists, user should populate it in advance correctly as below. This is to reduce template deployment time.
        /usr/bin/curl -k --max-redirs 10 https://github.com/moodle/moodle/archive/'$moodleVersion'.zip -L -o moodle.zip
        /usr/bin/unzip -q moodle.zip
        /bin/mv '$moodleUnzipDir' /moodle/html/moodle
    fi

    if [ "'$installGdprPluginsSwitch'" = "true" ]; then
        # install Moodle GDPR plugins (Note: This is only for Moodle versions 3.4.2+ or 3.3.5+ and will be included in Moodle 3.5, so no need for 3.5)
        curl -k --max-redirs 10 https://github.com/moodlehq/moodle-tool_policy/archive/'$moodleStableVersion'.zip -L -o plugin-policy.zip
        unzip -q plugin-policy.zip
        mv moodle-tool_policy-'$moodleStableVersion' /moodle/html/moodle/admin/tool/policy

        curl -k --max-redirs 10 https://github.com/moodlehq/moodle-tool_dataprivacy/archive/'$moodleStableVersion'.zip -L -o plugin-dataprivacy.zip
        unzip -q plugin-dataprivacy.zip
        mv moodle-tool_dataprivacy-'$moodleStableVersion' /moodle/html/moodle/admin/tool/dataprivacy
    fi

    if [ "'$installO365pluginsSwitch'" = "true" ]; then
        # install Office 365 plugins
        curl -k --max-redirs 10 https://github.com/Microsoft/o365-moodle/archive/'$o365pluginVersion'.zip -L -o o365.zip
        unzip -q o365.zip
        cp -r o365-moodle-'$o365pluginVersion'/* /moodle/html/moodle
        rm -rf o365-moodle-'$o365pluginVersion'
    fi

    if [ "'$searchType'" = "elastic" ]; then
        # Install ElasticSearch plugin
        /usr/bin/curl -k --max-redirs 10 https://github.com/catalyst/moodle-search_elastic/archive/master.zip -L -o plugin-elastic.zip
        /usr/bin/unzip -q plugin-elastic.zip
        /bin/mv moodle-search_elastic-master /moodle/html/moodle/search/engine/elastic

        # Install ElasticSearch plugin dependency
        /usr/bin/curl -k --max-redirs 10 https://github.com/catalyst/moodle-local_aws/archive/master.zip -L -o local-aws.zip
        /usr/bin/unzip -q local-aws.zip
        /bin/mv moodle-local_aws-master /moodle/html/moodle/local/aws

    elif [ "'$searchType'" = "azure" ]; then
        # Install Azure Search service plugin
        /usr/bin/curl -k --max-redirs 10 https://github.com/catalyst/moodle-search_azure/archive/master.zip -L -o plugin-azure-search.zip
        /usr/bin/unzip -q plugin-azure-search.zip
        /bin/mv moodle-search_azure-master /moodle/html/moodle/search/engine/azure
    fi

    if [ "'$installObjectFsSwitch'" = "true" ]; then
        # Install the ObjectFS plugin
        /usr/bin/curl -k --max-redirs 10 https://github.com/catalyst/moodle-tool_objectfs/archive/master.zip -L -o plugin-objectfs.zip
        /usr/bin/unzip -q plugin-objectfs.zip
        /bin/mv moodle-tool_objectfs-master /moodle/html/moodle/admin/tool/objectfs

        # Install the ObjectFS Azure library
        /usr/bin/curl -k --max-redirs 10 https://github.com/catalyst/moodle-local_azure_storage/archive/master.zip -L -o plugin-azurelibrary.zip
        /usr/bin/unzip -q plugin-azurelibrary.zip
        /bin/mv moodle-local_azure_storage-master /moodle/html/moodle/local/azure_storage
    fi
    cd /moodle
    rm -rf /moodle/tmp
    ' > /tmp/setup-moodle.sh 

    chmod 755 /tmp/setup-moodle.sh
    /tmp/setup-moodle.sh >> /tmp/setupmoodle.log

    # Build nginx and siteFqdn config by copying it from downloaded location
    # and then by replacing the variable values
    nginxConfLocation="/etc/nginx/nginx.conf"
    cp ${moodleStackConfigurationDownloadPath}/nginx.conf $nginxConfLocation
    sed -i "s/\${siteFQDN}/${siteFQDN}/g" $nginxConfLocation
    sed -i "s/\${PhpVer}/${PhpVer}/g" $nginxConfLocation

    siteFqdnConfLocation="/etc/nginx/sites-enabled/${siteFQDN}.conf"
    cp ${moodleStackConfigurationDownloadPath}/siteFqdn.conf $siteFqdnConfLocation
    sed -i "s/\${siteFQDN}/${siteFQDN}/g" $siteFqdnConfLocation
    sed -i "s/\${PhpVer}/${PhpVer}/g" $siteFqdnConfLocation

    if [ "$httpsTermination" = "VMSS" ]; then
        ### SSL cert ###
        if [ "$thumbprintSslCert" != "None" ]; then
            echo "Using VM's cert (/var/lib/waagent/$thumbprintSslCert.*) for SSL..."
            cat /var/lib/waagent/$thumbprintSslCert.prv > /moodle/certs/nginx.key
            cat /var/lib/waagent/$thumbprintSslCert.crt > /moodle/certs/nginx.crt
            if [ "$thumbprintCaCert" != "None" ]; then
                echo "CA cert was specified (/var/lib/waagent/$thumbprintCaCert.crt), so append it to nginx.crt..."
                cat /var/lib/waagent/$thumbprintCaCert.crt >> /moodle/certs/nginx.crt
            fi
        else
            echo -e "Generating SSL self-signed certificate"
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /moodle/certs/nginx.key -out /moodle/certs/nginx.crt -subj "/C=US/ST=WA/L=Redmond/O=IT/CN=$siteFQDN"
        fi
        chown www-data:www-data /moodle/certs/nginx.*
        chmod 0400 /moodle/certs/nginx.*
    fi

   # php config 
   PhpVer=$(get_php_version)
   PhpIni=/etc/php/${PhpVer}/fpm/php.ini
   sed -i "s/memory_limit.*/memory_limit = 512M/" $PhpIni
   sed -i "s/max_execution_time.*/max_execution_time = 18000/" $PhpIni
   sed -i "s/max_input_vars.*/max_input_vars = 100000/" $PhpIni
   sed -i "s/max_input_time.*/max_input_time = 600/" $PhpIni
   sed -i "s/upload_max_filesize.*/upload_max_filesize = 1024M/" $PhpIni
   sed -i "s/post_max_size.*/post_max_size = 1056M/" $PhpIni
   sed -i "s/;opcache.use_cwd.*/opcache.use_cwd = 1/" $PhpIni
   sed -i "s/;opcache.validate_timestamps.*/opcache.validate_timestamps = 1/" $PhpIni
   sed -i "s/;opcache.save_comments.*/opcache.save_comments = 1/" $PhpIni
   sed -i "s/;opcache.enable_file_override.*/opcache.enable_file_override = 0/" $PhpIni
   sed -i "s/;opcache.enable.*/opcache.enable = 1/" $PhpIni
   sed -i "s/;opcache.memory_consumption.*/opcache.memory_consumption = 256/" $PhpIni
   sed -i "s/;opcache.max_accelerated_files.*/opcache.max_accelerated_files = 8000/" $PhpIni

   # fpm config - overload this 
   cat <<EOF > /etc/php/${PhpVer}/fpm/pool.d/www.conf
[www]
user = www-data
group = www-data
listen = /run/php/php${PhpVer}-fpm.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 3000
pm.start_servers = 20 
pm.min_spare_servers = 22 
pm.max_spare_servers = 30 
EOF

   # Remove the default site. Moodle is the only site we want
   rm -f /etc/nginx/sites-enabled/default

   # restart Nginx
   sudo service nginx restart 

   # Configure varnish startup for 16.04
   VARNISHSTART="ExecStart=\/usr\/sbin\/varnishd -j unix,user=vcache -F -a :80 -T localhost:6082 -f \/etc\/varnish\/moodle.vcl -S \/etc\/varnish\/secret -s malloc,1024m -p thread_pool_min=200 -p thread_pool_max=4000 -p thread_pool_add_delay=2 -p timeout_linger=100 -p timeout_idle=30 -p send_timeout=1800 -p thread_pools=4 -p http_max_hdr=512 -p workspace_backend=512k"
   sed -i "s/^ExecStart.*/${VARNISHSTART}/" /lib/systemd/system/varnish.service

   # Configure varnish VCL for moodle
   cp ${moodleStackConfigurationDownloadPath}/moodle.vcl /etc/varnish/moodle.vcl

    # Restart Varnish
    systemctl daemon-reload
    service varnish restart

    if [ $dbServerType = "mysql" ]; then
        mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} -e "CREATE DATABASE ${moodledbname} CHARACTER SET utf8;"
        mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} -e "GRANT ALL ON ${moodledbname}.* TO ${moodledbuser} IDENTIFIED BY '${moodledbpass}';"

        echo "mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} -e \"CREATE DATABASE ${moodledbname};\"" >> /tmp/debug
        echo "mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} -e \"GRANT ALL ON ${moodledbname}.* TO ${moodledbuser} IDENTIFIED BY '${moodledbpass}';\"" >> /tmp/debug
    elif [ $dbServerType = "mssql" ]; then
        /opt/mssql-tools/bin/sqlcmd -S $mssqlIP -U $mssqladminlogin -P ${mssqladminpass} -Q "CREATE DATABASE ${moodledbname} ( MAXSIZE = $mssqlDbSize, EDITION = '$mssqlDbEdition', SERVICE_OBJECTIVE = '$mssqlDbServiceObjectiveName' )"
        /opt/mssql-tools/bin/sqlcmd -S $mssqlIP -U $mssqladminlogin -P ${mssqladminpass} -Q "CREATE LOGIN ${moodledbuser} with password = '${moodledbpass}'" 
        /opt/mssql-tools/bin/sqlcmd -S $mssqlIP -U $mssqladminlogin -P ${mssqladminpass} -d ${moodledbname} -Q "CREATE USER ${moodledbuser} FROM LOGIN ${moodledbuser}"
        /opt/mssql-tools/bin/sqlcmd -S $mssqlIP -U $mssqladminlogin -P ${mssqladminpass} -d ${moodledbname} -Q "exec sp_addrolemember 'db_owner','${moodledbuser}'" 
        
    else
        # Create postgres db
        echo "${postgresIP}:5432:postgres:${pgadminlogin}:${pgadminpass}" > /root/.pgpass
        chmod 600 /root/.pgpass
        psql -h $postgresIP -U $pgadminlogin -c "CREATE DATABASE ${moodledbname};" postgres
        psql -h $postgresIP -U $pgadminlogin -c "CREATE USER ${moodledbuser} WITH PASSWORD '${moodledbpass}';" postgres
        psql -h $postgresIP -U $pgadminlogin -c "GRANT ALL ON DATABASE ${moodledbname} TO ${moodledbuser};" postgres
        rm -f /root/.pgpass
    fi

    # Master config for syslog
    mkdir /var/log/sitelogs
    chown syslog.adm /var/log/sitelogs
    cat <<EOF >> /etc/rsyslog.conf
\$ModLoad imudp
\$UDPServerRun 514
EOF
    cat <<EOF >> /etc/rsyslog.d/40-sitelogs.conf
local1.*   /var/log/sitelogs/moodle/access.log
local1.err   /var/log/sitelogs/moodle/error.log
local2.*   /var/log/sitelogs/moodle/cron.log
EOF
    service rsyslog restart

    # Fire off moodle setup
    if [ "$httpsTermination" = "None" ]; then
        siteProtocol="http"
    else
        siteProtocol="https"
    fi
    if [ $dbServerType = "mysql" ]; then
        echo -e "cd /tmp; /usr/bin/php /moodle/html/moodle/admin/cli/install.php --chmod=770 --lang=en_us --wwwroot="$siteProtocol"://"$siteFQDN" --dataroot=/moodle/moodledata --dbhost="$mysqlIP" --dbname="$moodledbname" --dbuser="$azuremoodledbuser" --dbpass="$moodledbpass" --dbtype=mysqli --fullname='Moodle LMS' --shortname='Moodle' --adminuser=admin --adminpass="$adminpass" --adminemail=admin@"$siteFQDN" --non-interactive --agree-license --allow-unstable || true "
        cd /tmp; /usr/bin/php /moodle/html/moodle/admin/cli/install.php --chmod=770 --lang=en_us --wwwroot=$siteProtocol://$siteFQDN   --dataroot=/moodle/moodledata --dbhost=$mysqlIP   --dbname=$moodledbname   --dbuser=$azuremoodledbuser   --dbpass=$moodledbpass   --dbtype=mysqli --fullname='Moodle LMS' --shortname='Moodle' --adminuser=admin --adminpass=$adminpass   --adminemail=admin@$siteFQDN   --non-interactive --agree-license --allow-unstable || true

        if [ "$installObjectFsSwitch" = "true" ]; then
            mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} ${moodledbname} -e "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'enabletasks', 1);" 
            mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} ${moodledbname} -e "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'filesystem', '\\\tool_objectfs\\\azure_file_system');"
            mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} ${moodledbname} -e "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_accountname', '${storageAccountName}');"
            mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} ${moodledbname} -e "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_container', 'objectfs');"
            mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} ${moodledbname} -e "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_sastoken', '${sas}');"
        fi
    elif [ $dbServerType = "mssql" ]; then
        cd /tmp; /usr/bin/php /moodle/html/moodle/admin/cli/install.php --chmod=770 --lang=en_us --wwwroot=$siteProtocol://$siteFQDN   --dataroot=/moodle/moodledata --dbhost=$mssqlIP   --dbname=$moodledbname   --dbuser=$azuremoodledbuser   --dbpass=$moodledbpass   --dbtype=sqlsrv --fullname='Moodle LMS' --shortname='Moodle' --adminuser=admin --adminpass=$adminpass   --adminemail=admin@$siteFQDN   --non-interactive --agree-license --allow-unstable || true

        if [ "$installObjectFsSwitch" = "true" ]; then
            /opt/mssql-tools/bin/sqlcmd -S $mssqlIP -U $mssqladminlogin -P ${mssqladminpass} -d ${moodledbname} -Q "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'enabletasks', 1)" 
            /opt/mssql-tools/bin/sqlcmd -S $mssqlIP -U $mssqladminlogin -P ${mssqladminpass} -d ${moodledbname} -Q "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'filesystem', '\\\tool_objectfs\\\azure_file_system')"
            /opt/mssql-tools/bin/sqlcmd -S $mssqlIP -U $mssqladminlogin -P ${mssqladminpass} -d ${moodledbname} -Q "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_accountname', '${storageAccountName}')"
            /opt/mssql-tools/bin/sqlcmd -S $mssqlIP -U $mssqladminlogin -P ${mssqladminpass} -d ${moodledbname} -Q "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_container', 'objectfs')"
            /opt/mssql-tools/bin/sqlcmd -S $mssqlIP -U $mssqladminlogin -P ${mssqladminpass} -d${moodledbname} -Q "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_sastoken', '${sas}')"
        fi
    else
        echo -e "cd /tmp; /usr/bin/php /moodle/html/moodle/admin/cli/install.php --chmod=770 --lang=en_us --wwwroot="$siteProtocol"://"$siteFQDN" --dataroot=/moodle/moodledata --dbhost="$postgresIP" --dbname="$moodledbname" --dbuser="$azuremoodledbuser" --dbpass="$moodledbpass" --dbtype=pgsql --fullname='Moodle LMS' --shortname='Moodle' --adminuser=admin --adminpass="$adminpass" --adminemail=admin@"$siteFQDN" --non-interactive --agree-license --allow-unstable || true "
        cd /tmp; /usr/bin/php /moodle/html/moodle/admin/cli/install.php --chmod=770 --lang=en_us --wwwroot=$siteProtocol://$siteFQDN   --dataroot=/moodle/moodledata --dbhost=$postgresIP   --dbname=$moodledbname   --dbuser=$azuremoodledbuser   --dbpass=$moodledbpass   --dbtype=pgsql --fullname='Moodle LMS' --shortname='Moodle' --adminuser=admin --adminpass=$adminpass   --adminemail=admin@$siteFQDN   --non-interactive --agree-license --allow-unstable || true

        if [ "$installObjectFsSwitch" = "true" ]; then
            # Add the ObjectFS configuration to Moodle.
            echo "${postgresIP}:5432:${moodledbname}:${azuremoodledbuser}:${moodledbpass}" > /root/.pgpass
            chmod 600 /root/.pgpass
            psql -h $postgresIP -U $azuremoodledbuser -c "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'enabletasks', 1);" $moodledbname
            psql -h $postgresIP -U $azuremoodledbuser -c "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'filesystem', '\tool_objectfs\azure_file_system');" $moodledbname
            psql -h $postgresIP -U $azuremoodledbuser -c "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_accountname', '$storageAccountName');" $moodledbname
            psql -h $postgresIP -U $azuremoodledbuser -c "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_container', 'objectfs');" $moodledbname
            psql -h $postgresIP -U $azuremoodledbuser -c "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_sastoken', '$sas');" $moodledbname
        fi
    fi

    echo -e "\n\rDone! Installation completed!\n\r"

    if [ "$redisAuth" != "None" ]; then
        create_redis_configuration_in_moodledata_muc_config_php

        # redis configuration in /moodle/html/moodle/config.php
        sed -i "23 a \$CFG->session_redis_lock_expire = 7200;" /moodle/html/moodle/config.php
        sed -i "23 a \$CFG->session_redis_acquire_lock_timeout = 120;" /moodle/html/moodle/config.php
        sed -i "23 a \$CFG->session_redis_prefix = 'moodle_prod'; // Optional, default is don't set one." /moodle/html/moodle/config.php
        sed -i "23 a \$CFG->session_redis_database = 0;  // Optional, default is db 0." /moodle/html/moodle/config.php
        sed -i "23 a \$CFG->session_redis_port = 6379;  // Optional." /moodle/html/moodle/config.php
        sed -i "23 a \$CFG->session_redis_host = '$redisDns';" /moodle/html/moodle/config.php
        sed -i "23 a \$CFG->session_redis_auth = '$redisAuth';" /moodle/html/moodle/config.php
        sed -i "23 a \$CFG->session_handler_class = '\\\core\\\session\\\redis';" /moodle/html/moodle/config.php
    fi

    if [ "$httpsTermination" != "None" ]; then
        # We proxy ssl, so moodle needs to know this
        sed -i "23 a \$CFG->sslproxy  = 'true';" /moodle/html/moodle/config.php
    fi

    if [ "$searchType" = "elastic" ]; then
        # Set up elasticsearch plugin
        if [ "$tikaVmIP" = "none" ]; then
           sed -i "23 a \$CFG->forced_plugin_settings = ['search_elastic' => ['hostname' => 'http://$elasticVm1IP']];" /moodle/html/moodle/config.php
        else
           sed -i "23 a \$CFG->forced_plugin_settings = ['search_elastic' => ['hostname' => 'http://$elasticVm1IP', 'fileindexing' => 'true', 'tikahostname' => 'http://$tikaVmIP', 'tikaport' => '9998'],];" /moodle/html/moodle/config.php
        fi

        sed -i "23 a \$CFG->searchengine = 'elastic';" /moodle/html/moodle/config.php
        sed -i "23 a \$CFG->enableglobalsearch = 'true';" /moodle/html/moodle/config.php
        # create index
        php /moodle/html/moodle/search/cli/indexer.php --force --reindex

    elif [ "$searchType" = "azure" ]; then
        # Set up Azure Search service plugin
        if [ "$tikaVmIP" = "none" ]; then
           sed -i "23 a \$CFG->forced_plugin_settings = ['search_azure' => ['searchurl' => 'https://$azureSearchNameHost', 'apikey' => '$azureSearchKey']];" /moodle/html/moodle/config.php
        else
           sed -i "23 a \$CFG->forced_plugin_settings = ['search_azure' => ['searchurl' => 'https://$azureSearchNameHost', 'apikey' => '$azureSearchKey', 'fileindexing' => '1', 'tikahostname' => 'http://$tikaVmIP', 'tikaport' => '9998'],];" /moodle/html/moodle/config.php
        fi

        sed -i "23 a \$CFG->searchengine = 'azure';" /moodle/html/moodle/config.php
        sed -i "23 a \$CFG->enableglobalsearch = 'true';" /moodle/html/moodle/config.php
        # create index
        php /moodle/html/moodle/search/cli/indexer.php --force --reindex

    fi

    if [ "$installObjectFsSwitch" = "true" ]; then
        # Set the ObjectFS alternate filesystem
        sed -i "23 a \$CFG->alternative_file_system_class = '\\\tool_objectfs\\\azure_file_system';" /moodle/html/moodle/config.php
    fi

   if [ "$dbServerType" = "postgres" ]; then
     # Get a new version of Postgres to match Azure version
     add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main"
     wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
     apt-get update
     apt-get install -y postgresql-client-9.6
   fi

   # create cron entry
   # It is scheduled for once per minute. It can be changed as needed.
   echo '* * * * * www-data /usr/bin/php /moodle/html/moodle/admin/cli/cron.php 2>&1 | /usr/bin/logger -p local2.notice -t moodle' > /etc/cron.d/moodle-cron

   # Set up cronned sql dump
   if [ "$dbServerType" = "mysql" ]; then
      cat <<EOF > /etc/cron.d/sql-backup
22 02 * * * root /usr/bin/mysqldump -h $mysqlIP -u ${azuremoodledbuser} -p'${moodledbpass}' --databases ${moodledbname} | gzip > /moodle/db-backup.sql.gz
EOF
   elif [ "$dbServerType" = "postgres" ]; then
      cat <<EOF > /etc/cron.d/sql-backup
22 02 * * * root /usr/bin/pg_dump -Fc -h $postgresIP -U ${azuremoodledbuser} ${moodledbname} > /moodle/db-backup.sql
EOF
   #else # mssql. TODO It's missed earlier! Complete this!
   fi

   # Turning off services we don't need the controller running
   service nginx stop
   service php${PhpVer}-fpm stop
   service varnish stop
   service varnishncsa stop
   #service varnishlog stop

    # No need to run the commands below any more, as permissions & modes are already as such (no more "sudo -u www-data ...")
    # Leaving this code as a remark that we are explicitly leaving the ownership to root:root
#    if [ $fileServerType = "gluster" -o $fileServerType = "nfs" -o $fileServerType = "nfs-ha" ]; then
#       # make sure Moodle can read its code directory but not write
#       sudo chown -R root.root /moodle/html/moodle
#       sudo find /moodle/html/moodle -type f -exec chmod 644 '{}' \;
#       sudo find /moodle/html/moodle -type d -exec chmod 755 '{}' \;
#    fi
    # But now we need to adjust the moodledata and the certs directory ownerships, and the permission for the generated config.php
    sudo chown -R www-data.www-data /moodle/moodledata /moodle/certs
    sudo chmod +r /moodle/html/moodle/config.php

    # chmod /moodle for Azure NetApp Files (its default is 770!)
    if [ $fileServerType = "nfs-byo" ]; then
        sudo chmod +rx /moodle
    fi

   if [ $fileServerType = "azurefiles" ]; then
      # Delayed copy of moodle installation to the Azure Files share

      # First rename moodle directory to something else
      mv /moodle /moodle_old_delete_me
      # Then create the moodle share
      echo -e '\n\rCreating an Azure Files share for moodle'
      create_azure_files_moodle_share $storageAccountName $storageAccountKey /tmp/wabs.log $fileServerDiskSize
      # Set up and mount Azure Files share. Must be done after nginx is installed because of www-data user/group
      echo -e '\n\rSetting up and mounting Azure Files share on //'$storageAccountName'.file.core.windows.net/moodle on /moodle\n\r'
      setup_and_mount_azure_files_moodle_share $storageAccountName $storageAccountKey
      # Move the local installation over to the Azure Files
      echo -e '\n\rMoving locally installed moodle over to Azure Files'
      cp -a /moodle_old_delete_me/* /moodle || true # Ignore case sensitive directory copy failure
      rm -rf /moodle_old_delete_me || true # Keep the files just in case
   fi

   create_last_modified_time_update_script
   run_once_last_modified_time_update_script
   
}  > /tmp/install.log
