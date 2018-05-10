# Custom Script for Linux

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

glusterNode=$1
glusterVolume=$2 
siteFQDN=$3
syslogserver=$4
webServerType=$5
fileServerType=$6
storageAccountName=$7
storageAccountKey=$8
nfsVmName=$9

echo $glusterNode    >> /tmp/vars.txt
echo $glusterVolume  >> /tmp/vars.txt
echo $siteFQDN >> /tmp/vars.txt
echo $syslogserver >> /tmp/vars.txt
echo $webServerType >> /tmp/vars.txt
echo $fileServerType >> /tmp/vars.txt
echo $storageAccountName >> /tmp/vars.txt
echo $storageAccountKey >> /tmp/vars.txt
echo $nfsVmName >> /tmp/vars.txt

. ./helper_functions.sh
check_fileServerType_param $fileServerType

{
  # make sure the system does automatic update
  sudo apt-get -y update
  sudo apt-get -y install unattended-upgrades

  # install pre-requisites
  sudo apt-get -y install python-software-properties unzip rsyslog

  sudo apt-get -y install postgresql-client mysql-client git

  if [ $fileServerType = "gluster" ]; then
    #configure gluster repository & install gluster client
    sudo add-apt-repository ppa:gluster/glusterfs-3.8 -y
    sudo apt-get -y update
    sudo apt-get -y install glusterfs-client
  else # "azurefiles"
    sudo apt-get -y install cifs-utils
  fi

  # install the base stack
  sudo apt-get -y install nginx varnish php php-cli php-curl php-zip php-pear php-mbstring php-dev mcrypt

  if [ "$webServerType" = "apache" ]; then
    # install apache pacakges
    sudo apt-get -y install apache2 libapache2-mod-php
  else
    # for nginx-only option
    sudo apt-get -y install php-fpm
  fi

  # Moodle requirements
  sudo apt-get install -y graphviz aspell php-soap php-json php-redis php-bcmath php-gd php-pgsql php-mysql php-xmlrpc php-intl php-xml php-bz2
  install_php_sql_driver

  if [ $fileServerType = "gluster" ]; then
    # Mount gluster fs for /moodle
    sudo mkdir -p /moodle
    sudo chown www-data /moodle
    sudo chmod 770 /moodle
    sudo echo -e 'mount -t glusterfs '$glusterNode':/'$glusterVolume' /moodle'
    sudo mount -t glusterfs $glusterNode:/$glusterVolume /moodle
    sudo echo -e $glusterNode':/'$glusterVolume'   /moodle         glusterfs       defaults,_netdev,log-level=WARNING,log-file=/var/log/gluster.log 0 0' >> /etc/fstab
    sudo mount -a
  elif [ $fileServerType = "nfs" ]; then
    configure_nfs_client_and_mount $nfsVmName /moodle /moodle
  else # "azurefiles"
    setup_and_mount_azure_files_moodle_share $storageAccountName $storageAccountKey
  fi

  # Configure syslog to forward
  cat <<EOF >> /etc/rsyslog.conf
\$ModLoad imudp
\$UDPServerRun 514
EOF
  cat <<EOF >> /etc/rsyslog.d/40-remote.conf
local1.*   @${syslogserver}:514
local2.*   @${syslogserver}:514
EOF
  service syslog restart

  #NGINX / PHP config
   create_nginx_configuration ${siteFQDN}
 

   # Configure varnish startup for 16.04
   VARNISHSTART="ExecStart=\/usr\/sbin\/varnishd -j unix,user=vcache -F -a :80 -T localhost:6082 -f \/etc\/varnish\/moodle.vcl -S \/etc\/varnish\/secret -s malloc,1024m -p thread_pool_min=200 -p thread_pool_max=4000 -p thread_pool_add_delay=2 -p timeout_linger=100 -p timeout_idle=30 -p send_timeout=1800 -p thread_pools=4 -p http_max_hdr=512 -p workspace_backend=512k"
   sed -i "s/^ExecStart.*/${VARNISHSTART}/" /lib/systemd/system/varnish.service

 # Configure varnish VCL for moodle
   create_varnish_configuration
}  > /tmp/setup.log
