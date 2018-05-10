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

#parameters 
{
    moodleVersion=${1}
    glusterNode=${2}
    glusterVolume=${3}
    siteFQDN=${4}
    dbIP=${5}
    moodledbname=${6}
    moodledbuser=${7}
    moodledbpass=${8}
    adminpass=${9}
    dbadminlogin=${10}
    dbadminpass=${11}
    wabsacctname=${12}
    wabsacctkey=${13}
    azuremoodledbuser=${14}
    redisDns=${15}
    redisAuth=${16}
    elasticVm1IP=${17}
    installO365pluginsSwitch=${18}
    installElasticSearchSwitch=${19}
    dbServerType=${20}
    fileServerType=${21}
    serviceObjective=${22}
    serviceTier=${23}
    serviceSize=${24}


    echo $moodleVersion        >> /tmp/vars.txt
    echo $glusterNode          >> /tmp/vars.txt
    echo $glusterVolume        >> /tmp/vars.txt
    echo $siteFQDN             >> /tmp/vars.txt
    echo $dbIP                 >> /tmp/vars.txt
    echo $moodledbname         >> /tmp/vars.txt
    echo $moodledbuser         >> /tmp/vars.txt
    echo $moodledbpass         >> /tmp/vars.txt
    echo $adminpass            >> /tmp/vars.txt
    echo $dbadminlogin         >> /tmp/vars.txt
    echo $dbadminpass          >> /tmp/vars.txt
    echo $wabsacctname         >> /tmp/vars.txt
    echo $wabsacctkey          >> /tmp/vars.txt
    echo $azuremoodledbuser    >> /tmp/vars.txt
    echo $redisDns             >> /tmp/vars.txt
    echo $redisAuth            >> /tmp/vars.txt
    echo $elasticVm1IP         >> /tmp/vars.txt
    echo $installO365pluginsSwitch    >> /tmp/vars.txt
    echo $installElasticSearchSwitch  >> /tmp/vars.txt
    echo $dbServerType                >> /tmp/vars.txt
    echo $fileServerType              >> /tmp/vars.txt
    echo $serviceObjective	>> /tmp/vars.txt
    echo $serviceTier	>> /tmp/vars.txt
    echo $serviceSize	>> /tmp/vars.txt

    . ./helper_functions.sh
    check_fileServerType_param $fileServerType

    if [ "$dbServerType" = "mysql" ]; then
      mysqlIP=$dbIP
      mysqladminlogin=$dbadminlogin
      mysqladminpass=$dbadminpass
    elif [ "$dbServerType" = "mssql" ]; then
      mssqlIP=$dbIP
      mssqladminlogin=$dbadminlogin
      mssqladminpass=$dbadminpass

    elif [ "$dbServerType" = "postgres" ]; then
      postgresIP=$dbIP
      pgadminlogin=$dbadminlogin
      pgadminpass=$dbadminpass
    else
      echo "Invalid dbServerType ($dbServerType) given. Only 'mysql' or 'postgres' is allowed. Exiting"
      exit 1
    fi

    #Create fail2ban config
    create_fail2ban_configuration

    # create gluster, nfs or Azure Files mount point
    mkdir -p /moodle

    export DEBIAN_FRONTEND=noninteractive

    if [ $fileServerType = "gluster" ]; then
        # configure gluster repository & install gluster client
        sudo add-apt-repository ppa:gluster/glusterfs-3.8 -y                 >> /tmp/apt1.log
    elif [ $fileServerType = "nfs" ]; then
        # configure NFS server and export
        create_filesystem_with_raid /moodle /dev/md1 /dev/md1p1
        configure_nfs_server_and_export /moodle
    fi

    sudo apt-get -y update                                                   >> /tmp/apt2.log
    sudo apt-get -y --force-yes install rsyslog git                          >> /tmp/apt3.log

    if [ $fileServerType = "gluster" ]; then
        sudo apt-get -y --force-yes install glusterfs-client                 >> /tmp/apt3.log
    else # "azurefiles"
        sudo apt-get -y --force-yes install cifs-utils                       >> /tmp/apt3.log
    fi

    if [ $dbServerType = "mysql" ]; then
        sudo apt-get -y --force-yes install mysql-client >> /tmp/apt3.log
    else
        sudo apt-get -y --force-yes install postgresql-client >> /tmp/apt3.log
    fi

    # install azure cli & setup container
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
        sudo tee /etc/apt/sources.list.d/azure-cli.list

    sudo apt-key adv --keyserver packages.microsoft.com --recv-keys 52E16F86FEE04B979B07E28DB02C46DF417A0893 >> /tmp/apt4.log
    sudo apt-get -y install apt-transport-https >> /tmp/apt4.log
    sudo apt-get -y update > /dev/null
    sudo apt-get -y install azure-cli >> /tmp/apt4.log

    az storage container create \
        --name objectfs \
        --account-name $wabsacctname \
        --account-key $wabsacctkey \
        --public-access off \
        --fail-on-exist >> /tmp/wabs.log

    az storage container policy create \
        --account-name $wabsacctname \
        --account-key $wabsacctkey \
        --container-name objectfs \
        --name readwrite \
        --start $(date --date="1 day ago" +%F) \
        --expiry $(date --date="2199-01-01" +%F) \
        --permissions rw >> /tmp/wabs.log

    sas=$(az storage container generate-sas \
        --account-name $wabsacctname \
        --account-key $wabsacctkey \
        --name objectfs \
        --policy readwrite \
        --output tsv)

    if [ $fileServerType = "gluster" ]; then
        # mount gluster files system
        echo -e '\n\rInstalling GlusterFS on '$glusterNode':/'$glusterVolume '/moodle\n\r' 
        sudo mount -t glusterfs $glusterNode:/$glusterVolume /moodle
    fi
    
    # install pre-requisites
    sudo apt-get install -y --fix-missing python-software-properties unzip

    # install the entire stack
    sudo apt-get -y  --force-yes install nginx php-fpm varnish >> /tmp/apt5a.log
    sudo apt-get -y  --force-yes install php php-cli php-curl php-zip >> /tmp/apt5b.log

    # Moodle requirements
    sudo apt-get -y update > /dev/null
    sudo apt-get install -y --force-yes graphviz aspell php-common php-soap php-json php-redis > /tmp/apt6.log
    sudo apt-get install -y --force-yes php-bcmath php-gd php-xmlrpc php-intl php-xml php-bz2 php-pear php-mbstring php-dev mcrypt >> /tmp/apt6.log
    if [ $dbServerType = "mysql" ]; then
        sudo apt-get install -y --force-yes php-mysql
    elif [ $dbServerType = "mssql" ]; then
        install_php_sql_driver 
    else
        sudo apt-get install -y --force-yes php-pgsql
    fi

    # Set up initial moodle dirs
    mkdir -p /moodle/html
    mkdir -p /moodle/certs
    mkdir -p /moodle/moodledata
    chown -R www-data.www-data /moodle

    # install Moodle 
    echo '#!/bin/bash
    cd /tmp

    # downloading moodle 
    /usr/bin/curl -k --max-redirs 10 https://github.com/moodle/moodle/archive/'$moodleVersion'.zip -L -o moodle.zip
    /usr/bin/unzip -q moodle.zip
    /bin/mv -v moodle-'$moodleVersion' /moodle/html/moodle

    if [ "'$installO365pluginsSwitch'" = "True" ]; then
        # install Office 365 plugins
        curl -k --max-redirs 10 https://github.com/Microsoft/o365-moodle/archive/'$moodleVersion'.zip -L -o o365.zip
        unzip -q o365.zip
        cp -r o365-moodle-'$moodleVersion'/* /moodle/html/moodle
        rm -rf o365-moodle-'$moodleVersion'
    fi

    if [ "'$installElasticSearchSwitch'" = "True" ]; then
        # Install ElasticSearch plugin
        /usr/bin/curl -k --max-redirs 10 https://github.com/catalyst/moodle-search_elastic/archive/master.zip -L -o plugin-elastic.zip
        /usr/bin/unzip -q plugin-elastic.zip
        /bin/mkdir -p /moodle/html/moodle/search/engine/elastic
        /bin/cp -r moodle-search_elastic-master/* /moodle/html/moodle/search/engine/elastic
        /bin/rm -rf moodle-search_elastic-master

        # Install ElasticSearch plugin dependency
        /usr/bin/curl -k --max-redirs 10 https://github.com/catalyst/moodle-local_aws/archive/master.zip -L -o local-aws.zip
        /usr/bin/unzip -q local-aws.zip
        /bin/mkdir -p /moodle/html/moodle/local/aws
        /bin/cp -r moodle-local_aws-master/* /moodle/html/moodle/local/aws
    fi

    # Install the ObjectFS plugin
    /usr/bin/curl -k --max-redirs 10 https://github.com/catalyst/moodle-tool_objectfs/archive/master.zip -L -o plugin-objectfs.zip
    /usr/bin/unzip -q plugin-objectfs.zip
    /bin/mkdir -p /moodle/html/moodle/admin/tool/objectfs
    /bin/cp -r moodle-tool_objectfs-master/* /moodle/html/moodle/admin/tool/objectfs
    /bin/rm -rf moodle-tool_objectfs-master

    # Install the ObjectFS Azure library
    /usr/bin/curl -k --max-redirs 10 https://github.com/catalyst/moodle-local_azure_storage/archive/master.zip -L -o plugin-azurelibrary.zip
    /usr/bin/unzip -q plugin-azurelibrary.zip
    /bin/mkdir -p /moodle/html/moodle/local/azure_storage
    /bin/cp -r moodle-local_azure_storage-master/* /moodle/html/moodle/local/azure_storage
    /bin/rm -rf moodle-local_azure_storage-master
    ' > /tmp/setup-moodle.sh 

    chmod 755 /tmp/setup-moodle.sh
    sudo -u www-data /tmp/setup-moodle.sh >> /tmp/setupmoodle.log

   #NGINX / PHP config
   create_nginx_configuration ${siteFQDN}

   # Configure varnish startup for 16.04
   VARNISHSTART="ExecStart=\/usr\/sbin\/varnishd -j unix,user=vcache -F -a :80 -T localhost:6082 -f \/etc\/varnish\/moodle.vcl -S \/etc\/varnish\/secret -s malloc,1024m -p thread_pool_min=200 -p thread_pool_max=4000 -p thread_pool_add_delay=2 -p timeout_linger=100 -p timeout_idle=30 -p send_timeout=1800 -p thread_pools=4 -p http_max_hdr=512 -p workspace_backend=512k"
   sed -i "s/^ExecStart.*/${VARNISHSTART}/" /lib/systemd/system/varnish.service

   # Configure varnish VCL for moodle
   create_varnish_configuration

    if [ $dbServerType = "mysql" ]; then
        mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} -e "CREATE DATABASE ${moodledbname} CHARACTER SET utf8;"
        mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} -e "GRANT ALL ON ${moodledbname}.* TO ${moodledbuser} IDENTIFIED BY '${moodledbpass}';"

        echo "mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} -e \"CREATE DATABASE ${moodledbname};\"" >> /tmp/debug
        echo "mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} -e \"GRANT ALL ON ${moodledbname}.* TO ${moodledbuser} IDENTIFIED BY '${moodledbpass}';\"" >> /tmp/debug
    elif [ $dbServerType = "mssql" ]; then
        /opt/mssql-tools/bin/sqlcmd -S $mssqlIP -U $mssqladminlogin -P ${mssqladminpass} -Q "CREATE DATABASE ${moodledbname} ( MAXSIZE = $serviceSize, EDITION = '$serviceTier', SERVICE_OBJECTIVE = '$serviceObjective' )"
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
    if [ $dbServerType = "mysql" ]; then
        echo -e "cd /tmp; sudo -u www-data /usr/bin/php /moodle/html/moodle/admin/cli/install.php --chmod=770 --lang=en_us --wwwroot=https://"$siteFQDN" --dataroot=/moodle/moodledata --dbhost="$mysqlIP" --dbname="$moodledbname" --dbuser="$azuremoodledbuser" --dbpass="$moodledbpass" --dbtype=mysqli --fullname='Moodle LMS' --shortname='Moodle' --adminuser=admin --adminpass="$adminpass" --adminemail=admin@"$siteFQDN" --non-interactive --agree-license --allow-unstable || true "
        cd /tmp; sudo -u www-data /usr/bin/php /moodle/html/moodle/admin/cli/install.php --chmod=770 --lang=en_us --wwwroot=https://$siteFQDN   --dataroot=/moodle/moodledata --dbhost=$mysqlIP   --dbname=$moodledbname   --dbuser=$azuremoodledbuser   --dbpass=$moodledbpass   --dbtype=mysqli --fullname='Moodle LMS' --shortname='Moodle' --adminuser=admin --adminpass=$adminpass   --adminemail=admin@$siteFQDN   --non-interactive --agree-license --allow-unstable || true

        mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} ${moodledbname} -e "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'enabletasks', 1);" 
        mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} ${moodledbname} -e "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'filesystem', '\\\tool_objectfs\\\azure_file_system');"
        mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} ${moodledbname} -e "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_accountname', '${wabsacctname}');"
        mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} ${moodledbname} -e "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_container', 'objectfs');"
        mysql -h $mysqlIP -u $mysqladminlogin -p${mysqladminpass} ${moodledbname} -e "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_sastoken', '${sas}');"
    elif [ $dbServerType = "mssql" ]; then
        cd /tmp; sudo -u www-data /usr/bin/php /moodle/html/moodle/admin/cli/install.php --chmod=770 --lang=en_us --wwwroot=https://$siteFQDN   --dataroot=/moodle/moodledata --dbhost=$mssqlIP   --dbname=$moodledbname   --dbuser=$azuremoodledbuser   --dbpass=$moodledbpass   --dbtype=sqlsrv --fullname='Moodle LMS' --shortname='Moodle' --adminuser=admin --adminpass=$adminpass   --adminemail=admin@$siteFQDN   --non-interactive --agree-license --allow-unstable || true

       /opt/mssql-tools/bin/sqlcmd -S $mssqlIP -U $mssqladminlogin -P ${mssqladminpass} -d ${moodledbname} -Q "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'enabletasks', 1)" 
       /opt/mssql-tools/bin/sqlcmd -S $mssqlIP -U $mssqladminlogin -P ${mssqladminpass} -d ${moodledbname} -Q "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'filesystem', '\\\tool_objectfs\\\azure_file_system')"
       /opt/mssql-tools/bin/sqlcmd -S $mssqlIP -U $mssqladminlogin -P ${mssqladminpass} -d ${moodledbname} -Q "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_accountname', '${wabsacctname}')"
       /opt/mssql-tools/bin/sqlcmd -S $mssqlIP -U $mssqladminlogin -P ${mssqladminpass} -d ${moodledbname} -Q "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_container', 'objectfs')"
       /opt/mssql-tools/bin/sqlcmd -S $mssqlIP -U $mssqladminlogin -P ${mssqladminpass} -d${moodledbname} -Q "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_sastoken', '${sas}')"

    else
        echo -e "cd /tmp; sudo -u www-data /usr/bin/php /moodle/html/moodle/admin/cli/install.php --chmod=770 --lang=en_us --wwwroot=https://"$siteFQDN" --dataroot=/moodle/moodledata --dbhost="$postgresIP" --dbname="$moodledbname" --dbuser="$azuremoodledbuser" --dbpass="$moodledbpass" --dbtype=pgsql --fullname='Moodle LMS' --shortname='Moodle' --adminuser=admin --adminpass="$adminpass" --adminemail=admin@"$siteFQDN" --non-interactive --agree-license --allow-unstable || true "
        cd /tmp; sudo -u www-data /usr/bin/php /moodle/html/moodle/admin/cli/install.php --chmod=770 --lang=en_us --wwwroot=https://$siteFQDN   --dataroot=/moodle/moodledata --dbhost=$postgresIP   --dbname=$moodledbname   --dbuser=$azuremoodledbuser   --dbpass=$moodledbpass   --dbtype=pgsql --fullname='Moodle LMS' --shortname='Moodle' --adminuser=admin --adminpass=$adminpass   --adminemail=admin@$siteFQDN   --non-interactive --agree-license --allow-unstable || true

        # Add the ObjectFS configuration to Moodle.
        echo "${postgresIP}:5432:${moodledbname}:${azuremoodledbuser}:${moodledbpass}" > /root/.pgpass
        chmod 600 /root/.pgpass
        psql -h $postgresIP -U $azuremoodledbuser -c "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'enabletasks', 1);" $moodledbname
        psql -h $postgresIP -U $azuremoodledbuser -c "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'filesystem', '\tool_objectfs\azure_file_system');" $moodledbname
        psql -h $postgresIP -U $azuremoodledbuser -c "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_accountname', '$wabsacctname');" $moodledbname
        psql -h $postgresIP -U $azuremoodledbuser -c "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_container', 'objectfs');" $moodledbname
        psql -h $postgresIP -U $azuremoodledbuser -c "INSERT INTO mdl_config_plugins (plugin, name, value) VALUES ('tool_objectfs', 'azure_sastoken', '$sas');" $moodledbname
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

    # We proxy ssl, so moodle needs to know this
    sed -i "23 a \$CFG->sslproxy  = 'true';" /moodle/html/moodle/config.php

    if [ "$installElasticSearchSwitch" = "True" ]; then
        # Set up elasticsearch plugin
        sed -i "23 a \$CFG->forced_plugin_settings = ['search_elastic' => ['hostname' => 'http://$elasticVm1IP']];" /moodle/html/moodle/config.php
        sed -i "23 a \$CFG->searchengine = 'elastic';" /moodle/html/moodle/config.php
        sed -i "23 a \$CFG->enableglobalsearch = 'true';" /moodle/html/moodle/config.php
    fi

    # Set the ObjectFS alternate filesystem
    sed -i "23 a \$CFG->alternative_file_system_class = '\\\tool_objectfs\\\azure_file_system';" /moodle/html/moodle/config.php

   if [ "$dbServerType" = "postgres" ]; then
     # Get a new version of Postgres to match Azure version
     add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main"
     wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
     apt-get update
     apt-get install postgresql-client-9.6
   fi

   # create cron entry
   # It is scheduled for once per minute. It can be changed as needed.
   echo '* * * * * www-data /usr/bin/php /moodle/html/moodle/admin/cli/cron.php 2>&1 | /usr/bin/logger -p local2.notice -t moodle' > /etc/cron.d/moodle-cron

   # Set up cronned sql dump
   if [ "$dbServerType" = "mysql" ]; then
      cat <<EOF > /etc/cron.d/sql-backup
22 02 * * * root /usr/bin/mysqldump -h $mysqlIP -u ${azuremoodledbuser} -p'${moodledbpass}' --databases ${moodledbname} | gzip > /moodle/db-backup.sql.gz
EOF
   else
      cat <<EOF > /etc/cron.d/sql-backup
22 02 * * * root /usr/bin/pg_dump -Fc -h $postgresIP -U ${azuremoodledbuser} ${moodledbname} > /moodle/db-backup.sql
EOF
   fi

   # Turning off services we don't need the jumpbox running
   service nginx stop
   service php7.0-fpm stop
   service varnish stop
   service varnishncsa stop
   service varnishlog stop

   if [ $fileServerType = "gluster" -o $fileServerType = "nfs" ]; then
      # make sure Moodle can read its code directory but not write
      sudo chown -R root.root /moodle/html/moodle
      sudo find /moodle/html/moodle -type f -exec chmod 644 '{}' \;
      sudo find /moodle/html/moodle -type d -exec chmod 755 '{}' \;
   fi

   if [ $fileServerType = "azurefiles" ]; then
      # Delayed copy of moodle installation to the Azure Files share

      # First rename moodle directory to something else
      mv /moodle /moodle_old_delete_me
      # Then create the moodle share
      echo -e '\n\rCreating an Azure Files share for moodle'
      create_azure_files_moodle_share $wabsacctname $wabsacctkey /tmp/wabs.log
      # Set up and mount Azure Files share. Must be done after nginx is installed because of www-data user/group
      echo -e '\n\rSetting up and mounting Azure Files share on //'$wabsacctname'.file.core.windows.net/moodle on /moodle\n\r'
      setup_and_mount_azure_files_moodle_share $wabsacctname $wabsacctkey
      # Move the local installation over to the Azure Files
      echo -e '\n\rMoving locally installed moodle over to Azure Files'
      cp -a /moodle_old_delete_me/* /moodle || true # Ignore case sensitive directory copy failure
      # rm -rf /moodle_old_delete_me || true # Keep the files just in case
   fi

}  > /tmp/install.log
