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
set -ex
echo "### Script Start `date`###"

moodle_on_azure_configs_json_path=${1}

. ./helper_functions.sh

get_setup_params_from_configs_json $moodle_on_azure_configs_json_path || exit 99

echo $glusterNode    >> /tmp/vars.txt
echo $glusterVolume  >> /tmp/vars.txt
echo $siteFQDN >> /tmp/vars.txt
echo $httpsTermination >> /tmp/vars.txt
echo $syslogServer >> /tmp/vars.txt
echo $webServerType >> /tmp/vars.txt
echo $dbServerType >> /tmp/vars.txt
echo $fileServerType >> /tmp/vars.txt
echo $storageAccountName >> /tmp/vars.txt
echo $storageAccountKey >> /tmp/vars.txt
echo $nfsVmName >> /tmp/vars.txt
echo $nfsByoIpExportPath >> /tmp/vars.txt
echo $htmlLocalCopySwitch >> /tmp/vars.txt
echo $phpVersion          >> /tmp/vars.txt



check_fileServerType_param $fileServerType

{
  set -ex
  echo "### Function Start `date`###"

  # add azure-cli repository
  curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
  AZ_REPO=$(lsb_release -cs)
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |  tee /etc/apt/sources.list.d/azure-cli.list
  
  # add PHP-FPM repository 
  add-apt-repository ppa:ondrej/php -y > /dev/null 2>&1

  apt-get -qq -o=Dpkg::Use-Pty=0 update 

  # install pre-requisites including VARNISH and PHP-FPM
  export DEBIAN_FRONTEND=noninteractive
  apt-get --yes \
    --no-install-recommends \
    -qq -o=Dpkg::Use-Pty=0 \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    install \
    azure-cli \
    ca-certificates \
    curl \
    apt-transport-https \
    lsb-release gnupg \
    software-properties-common \
    unzip \
    rsyslog \
    postgresql-client \
    mysql-client \
    git \
    unattended-upgrades \
    tuned \
    varnish \
    php$phpVersion \
    php$phpVersion-cli \
    php$phpVersion-curl \
    php$phpVersion-zip \
    php-pear \
    php$phpVersion-mbstring \
    mcrypt \
    php$phpVersion-dev \
    graphviz \
    aspell \
    php$phpVersion-soap \
    php$phpVersion-json \
    php$phpVersion-redis \
    php$phpVersion-bcmath \
    php$phpVersion-gd \
    php$phpVersion-pgsql \
    php$phpVersion-mysql \
    php$phpVersion-xmlrpc \
    php$phpVersion-intl \
    php$phpVersion-xml \
    php$phpVersion-bz2

  # install azcopy
  wget -q -O azcopy_v10.tar.gz https://aka.ms/downloadazcopy-v10-linux && tar -xf azcopy_v10.tar.gz --strip-components=1 && mv ./azcopy /usr/bin/

  # kernel settings
  cat <<EOF > /etc/sysctl.d/99-network-performance.conf
net.core.somaxconn = 65536
net.core.netdev_max_backlog = 5000
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_wmem = 4096 12582912 16777216
net.ipv4.tcp_rmem = 4096 12582912 16777216
net.ipv4.route.flush = 1
net.ipv4.tcp_max_syn_backlog = 8096
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 10240 65535
EOF
  # apply the new kernel settings
  sysctl -p /etc/sysctl.d/99-network-performance.conf

  # scheduling IRQ interrupts on the last two cores of the cpu
  # masking 0011 or 00000011 the result will always be 3 echo "obase=16;ibase=2;0011" | bc | tr '[:upper:]' '[:lower:]'
  if [ -f /etc/default/irqbalance ]; then
    sed -i "s/\#IRQBALANCE_BANNED_CPUS\=/IRQBALANCE_BANNED_CPUS\=3/g" /etc/default/irqbalance
    systemctl restart irqbalance.service 
  fi

  # configuring tuned for throughput-performance
  systemctl enable tuned
  tuned-adm profile throughput-performance

  if [ $fileServerType = "gluster" ]; then
    #configure gluster repository & install gluster client
    add-apt-repository ppa:gluster/glusterfs-3.10 -y
    apt-get -y update
    apt-get -y -qq -o=Dpkg::Use-Pty=0 install glusterfs-client
  elif [ "$fileServerType" = "azurefiles" ]; then
    apt-get -y -qq -o=Dpkg::Use-Pty=0 install cifs-utils
  fi

  if [ "$webServerType" = "nginx" -o "$httpsTermination" = "VMSS" ]; then
    apt-get --yes -qq -o=Dpkg::Use-Pty=0 install nginx
  fi
   
  if [ "$webServerType" = "apache" ]; then
    # install apache pacakges
    apt-get --yes -qq -o=Dpkg::Use-Pty=0 install apache2 libapache2-mod-php
  else
    # for nginx-only option
    apt-get --yes -qq -o=Dpkg::Use-Pty=0 install php$phpVersion-fpm
  fi
   
  # Moodle requirements
  if [ "$dbServerType" = "mssql" ]; then
    install_php_mssql_driver
  fi
   
  # PHP Version
  PhpVer=$(get_php_version)

  if [ $fileServerType = "gluster" ]; then
    # Mount gluster fs for /moodle
    sudo mkdir -p /moodle
    sudo chown www-data /moodle
    sudo chmod 770 /moodle
    sudo echo -e 'Adding Gluster FS to /etc/fstab and mounting it'
    setup_and_mount_gluster_moodle_share $glusterNode $glusterVolume
  elif [ $fileServerType = "nfs" ]; then
    # mount NFS export (set up on controller VM--No HA)
    echo -e '\n\rMounting NFS export from '$nfsVmName':/moodle on /moodle and adding it to /etc/fstab\n\r'
    configure_nfs_client_and_mount $nfsVmName /moodle /moodle
  elif [ $fileServerType = "nfs-ha" ]; then
    # mount NFS-HA export
    echo -e '\n\rMounting NFS export from '$nfsHaLbIP':'$nfsHaExportPath' on /moodle and adding it to /etc/fstab\n\r'
    configure_nfs_client_and_mount $nfsHaLbIP $nfsHaExportPath /moodle
  elif [ $fileServerType = "nfs-byo" ]; then
    # mount NFS-BYO export
    echo -e '\n\rMounting NFS export from '$nfsByoIpExportPath' on /moodle and adding it to /etc/fstab\n\r'
    configure_nfs_client_and_mount0 $nfsByoIpExportPath /moodle
  else # "azurefiles"
    setup_and_mount_azure_files_moodle_share $storageAccountName $storageAccountKey
  fi

  # Configure syslog to forward
  cat <<EOF >> /etc/rsyslog.conf
\$ModLoad imudp
\$UDPServerRun 514
EOF
  cat <<EOF >> /etc/rsyslog.d/40-remote.conf
local1.*   @${syslogServer}:514
local2.*   @${syslogServer}:514
EOF
  service syslog restart

  if [ "$webServerType" = "nginx" -o "$httpsTermination" = "VMSS" ]; then
    # Build nginx config
    cat <<EOF > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
	worker_connections 8192;
  multi_accept on;
  use epoll;
}

worker_rlimit_nofile 100000;

http {

  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  keepalive_timeout 65;
  types_hash_max_size 2048;
  client_max_body_size 0;
  proxy_max_temp_file_size 0;
  server_names_hash_bucket_size  128;
  fastcgi_buffers 16 16k; 
  fastcgi_buffer_size 32k;
  proxy_buffering off;
  include /etc/nginx/mime.types;
  default_type application/octet-stream;

  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;

  open_file_cache max=20000 inactive=20s;
  open_file_cache_valid 30s;
  open_file_cache_min_uses 2;
  open_file_cache_errors on;

  set_real_ip_from   127.0.0.1;
  real_ip_header      X-Forwarded-For;
  #upgrading to TLSv1.2 and droping 1 & 1.1
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers off;
  #adding ssl ciphers
  ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;

  gzip on;
  gzip_disable "msie6";
  gzip_vary on;
  gzip_proxied any;
  gzip_comp_level 6;
  gzip_buffers 16 8k;
  gzip_http_version 1.1;
  gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
EOF
    if [ "$httpsTermination" != "None" ]; then
      cat <<EOF >> /etc/nginx/nginx.conf
  map \$http_x_forwarded_proto \$fastcgi_https {                                                                                          
    default \$https;                                                                                                                   
    http '';                                                                                                                          
    https on;                                                                                                                         
  }
EOF
    fi

    cat <<EOF >> /etc/nginx/nginx.conf
  log_format moodle_combined '\$remote_addr - \$upstream_http_x_moodleuser [\$time_local] '
                             '"\$request" \$status \$body_bytes_sent '
                             '"\$http_referer" "\$http_user_agent"';


  include /etc/nginx/conf.d/*.conf;
  include /etc/nginx/sites-enabled/*;
}
EOF
  fi # if [ "$webServerType" = "nginx" -o "$httpsTermination" = "VMSS" ];

  # Set up html dir local copy if specified
  htmlRootDir="/moodle/html/moodle"
  if [ "$htmlLocalCopySwitch" = "true" ]; then
    if [ "$fileServerType" = "azurefiles" ]; then
      mkdir -p /var/www/html
      ACCOUNT_KEY="$storageAccountKey"
      NAME="$storageAccountName"
      END=`date -u -d "60 minutes" '+%Y-%m-%dT%H:%M:00Z'`
      htmlRootDir="/var/www/html/moodle"

      sas=$(az storage share generate-sas \
        -n moodle \
        --account-key $ACCOUNT_KEY \
        --account-name $NAME \
        --https-only \
        --permissions lr \
        --expiry $END -o tsv)

      export AZCOPY_CONCURRENCY_VALUE='48'
      export AZCOPY_BUFFER_GB='4'

      azcopy --log-level ERROR copy "https://$NAME.file.core.windows.net/moodle/html/moodle/*?$sas" $htmlRootDir --recursive
      chown www-data:www-data -R $htmlRootDir && sync
      setup_html_local_copy_cron_job
    fi
    if [ "$fileServerType" = "nfs" -o "$fileServerType" = "nfs-ha" -o "$fileServerType" = "nfs-byo" -o "$fileServerType" = "gluster" ]; then
      mkdir -p /var/www/html/moodle
      rsync -a /moodle/html/moodle/ $htmlRootDir/
      chown www-data:www-data -R $htmlRootDir && sync
      setup_html_local_copy_cron_job
    fi
  fi

  if [ "$httpsTermination" = "VMSS" ]; then
    # Configure nginx/https
    cat <<EOF >> /etc/nginx/sites-enabled/${siteFQDN}.conf
server {
        listen 443 ssl http2;
        root ${htmlRootDir};
	      index index.php index.html index.htm;

        ssl on;
        ssl_certificate /moodle/certs/nginx.crt;
        ssl_certificate_key /moodle/certs/nginx.key;
        ssl_session_timeout 1d;
        ssl_session_cache shared:MozSSL:10m;  # about 40000 sessions
        ssl_session_tickets off;

        # Log to syslog
        error_log syslog:server=localhost,facility=local1,severity=error,tag=moodle;
        access_log syslog:server=localhost,facility=local1,severity=notice,tag=moodle moodle_combined;

        # Log XFF IP instead of varnish
        set_real_ip_from    10.0.0.0/8;
        set_real_ip_from    127.0.0.1;
        set_real_ip_from    172.16.0.0/12;
        set_real_ip_from    192.168.0.0/16;
        real_ip_header      X-Forwarded-For;
        real_ip_recursive   on;

        location / {
          proxy_set_header Host \$host;
          proxy_set_header HTTP_REFERER \$http_referer;
          proxy_set_header X-Forwarded-Host \$host;
          proxy_set_header X-Forwarded-Server \$host;
          proxy_set_header X-Forwarded-Proto https;
          proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
          proxy_pass http://localhost:80;

          proxy_next_upstream error timeout http_502 http_504;
          proxy_connect_timeout       3600;
          proxy_send_timeout          3600;
          proxy_read_timeout          3600;
          send_timeout                3600;
        }
}

EOF
  fi

  if [ "$webServerType" = "nginx" ]; then
    cat <<EOF >> /etc/nginx/sites-enabled/${siteFQDN}.conf
server {
        listen 81 default;
        server_name ${siteFQDN};
        root ${htmlRootDir};
	index index.php index.html index.htm;

        # Log to syslog
        error_log syslog:server=localhost,facility=local1,severity=error,tag=moodle;
        access_log syslog:server=localhost,facility=local1,severity=notice,tag=moodle moodle_combined;

        # Log XFF IP instead of varnish
        set_real_ip_from    10.0.0.0/8;
        set_real_ip_from    127.0.0.1;
        set_real_ip_from    172.16.0.0/12;
        set_real_ip_from    192.168.0.0/16;
        real_ip_header      X-Forwarded-For;
        real_ip_recursive   on;
EOF
    if [ "$httpsTermination" != "None" ]; then
      cat <<EOF >> /etc/nginx/sites-enabled/${siteFQDN}.conf
        # Redirect to https
        if (\$http_x_forwarded_proto != https) {
                return 301 https://\$server_name\$request_uri;
        }
        rewrite ^/(.*\.php)(/)(.*)$ /\$1?file=/\$3 last;
EOF
    fi
    cat <<EOF >> /etc/nginx/sites-enabled/${siteFQDN}.conf
        # Filter out php-fpm status page
        location ~ ^/server-status {
            return 404;
        }

	location / {
		try_files \$uri \$uri/index.php?\$query_string;
	}
 
        location ~ [^/]\.php(/|$) {
          fastcgi_split_path_info ^(.+?\.php)(/.*)$;
          if (!-f \$document_root\$fastcgi_script_name) {
                  return 404;
          }
 
          fastcgi_buffers 16 16k;
          fastcgi_buffer_size 32k;
          fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
          fastcgi_pass backend;
          fastcgi_param PATH_INFO \$fastcgi_path_info;
          fastcgi_read_timeout 3600;
          fastcgi_index index.php;
          include fastcgi_params;
        }
}

upstream backend {
        server unix:/run/php/php${PhpVer}-fpm.sock fail_timeout=1s;
        server unix:/run/php/php${PhpVer}-fpm-backup.sock backup;
}  

EOF
  fi

  if [ "$webServerType" = "apache" ]; then
    # Configure Apache/php
    sed -i "s/Listen 80/Listen 81/" /etc/apache2/ports.conf
    a2enmod rewrite && a2enmod remoteip && a2enmod headers

    cat <<EOF >> /etc/apache2/sites-enabled/${siteFQDN}.conf
<VirtualHost *:81>
	ServerName ${siteFQDN}

	ServerAdmin webmaster@localhost
	DocumentRoot ${htmlRootDir}

	<Directory ${htmlRootDir}>
		Options FollowSymLinks
		AllowOverride All
		Require all granted
	</Directory>
EOF
    if [ "$httpsTermination" != "None" ]; then
      cat <<EOF >> /etc/apache2/sites-enabled/${siteFQDN}.conf
    # Redirect unencrypted direct connections to HTTPS
    <IfModule mod_rewrite.c>
      RewriteEngine on
      RewriteCond %{HTTP:X-Forwarded-Proto} !https [NC]
      RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [L,R=301]
    </IFModule>
EOF
    fi
    cat <<EOF >> /etc/apache2/sites-enabled/${siteFQDN}.conf
    # Log X-Forwarded-For IP address instead of varnish (127.0.0.1)
    SetEnvIf X-Forwarded-For "^.*\..*\..*\..*" forwarded
    LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%{X-Forwarded-For}i %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" forwarded
	ErrorLog "|/usr/bin/logger -t moodle -p local1.error"
    CustomLog "|/usr/bin/logger -t moodle -p local1.notice" combined env=!forwarded
    CustomLog "|/usr/bin/logger -t moodle -p local1.notice" forwarded env=forwarded

</VirtualHost>
EOF
  fi # if [ "$webServerType" = "apache" ];

   # php config 
   if [ "$webServerType" = "apache" ]; then
     PhpIni=/etc/php/${PhpVer}/apache2/php.ini
   else
     PhpIni=/etc/php/${PhpVer}/fpm/php.ini
   fi
   sed -i "s/memory_limit.*/memory_limit = 512M/" $PhpIni
   sed -i "s/max_execution_time.*/max_execution_time = 18000/" $PhpIni
   sed -i "s/max_input_vars.*/max_input_vars = 100000/" $PhpIni
   sed -i "s/max_input_time.*/max_input_time = 600/" $PhpIni
   #*** Rafael Silva -> Change upload_max_filesize and post_max_size from 1024M to 1056M
   sed -i "s/upload_max_filesize.*/upload_max_filesize = 1056M/" $PhpIni
   sed -i "s/post_max_size.*/post_max_size = 1056M/" $PhpIni
   #***
   sed -i "s/;opcache.use_cwd.*/opcache.use_cwd = 1/" $PhpIni
   sed -i "s/;opcache.validate_timestamps.*/opcache.validate_timestamps = 1/" $PhpIni
   sed -i "s/;opcache.save_comments.*/opcache.save_comments = 1/" $PhpIni
   sed -i "s/;opcache.enable_file_override.*/opcache.enable_file_override = 0/" $PhpIni
   sed -i "s/;opcache.enable.*/opcache.enable = 1/" $PhpIni
   sed -i "s/;opcache.memory_consumption.*/opcache.memory_consumption = 512/" $PhpIni
   sed -i "s/;opcache.max_accelerated_files.*/opcache.max_accelerated_files = 20000/" $PhpIni
    
   # Remove the default site. Moodle is the only site we want
   rm -f /etc/nginx/sites-enabled/default
   if [ "$webServerType" = "apache" ]; then
     rm -f /etc/apache2/sites-enabled/000-default.conf
   fi

   if [ "$webServerType" = "nginx" -o "$httpsTermination" = "VMSS" ]; then
     # update startup script to wait for certificate in /moodle mount
     setup_moodle_mount_dependency_for_systemd_service nginx || exit 1
     # restart Nginx
     sudo service nginx restart 
   fi

   # Configure varnish startup for 18.04
   VARNISHSTART="ExecStart=\/usr\/sbin\/varnishd -j unix,user=vcache -F -a :80 -T localhost:6082 -f \/etc\/varnish\/moodle.vcl -S \/etc\/varnish\/secret -s malloc,4096m -p thread_pool_min=1000 -p thread_pool_max=4000 -p thread_pool_add_delay=0.1 -p timeout_linger=10 -p timeout_idle=30 -p send_timeout=1800 -p thread_pools=2 -p http_max_hdr=512 -p workspace_backend=512k"
   sed -i "s/^ExecStart.*/${VARNISHSTART}/" /lib/systemd/system/varnish.service

   # Configure varnish VCL for moodle
   cat <<EOF >> /etc/varnish/moodle.vcl
vcl 4.0;

import std;
import directors;
backend default {
    .host = "localhost";
    .port = "81";
    .first_byte_timeout = 3600s;
    .connect_timeout = 600s;
    .between_bytes_timeout = 600s;
}

sub vcl_recv {
    # Varnish does not support SPDY or HTTP/2.0 untill we upgrade to Varnish 5.0
    if (req.method == "PRI") {
        return (synth(405));
    }

    if (req.restarts == 0) {
      if (req.http.X-Forwarded-For) {
        set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
      } else {
        set req.http.X-Forwarded-For = client.ip;
      }
    }

    # Non-RFC2616 or CONNECT HTTP requests methods filtered. Pipe requests directly to backend
    if (req.method != "GET" &&
        req.method != "HEAD" &&
        req.method != "PUT" &&
        req.method != "POST" &&
        req.method != "TRACE" &&
        req.method != "OPTIONS" &&
        req.method != "DELETE") {
      return (pipe);
    }

    # Varnish don't mess with healthchecks
    if (req.url ~ "^/admin/tool/heartbeat" || req.url ~ "^/healthcheck.php")
    {
        return (pass);
    }

    # Pipe requests to backup.php straight to backend - prevents problem with progress bar long polling 503 problem
    # This is here because backup.php is POSTing to itself - Filter before !GET&&!HEAD
    if (req.url ~ "^/backup/backup.php")
    {
        return (pipe);
    }

    # Varnish only deals with GET and HEAD by default. If request method is not GET or HEAD, pass request to backend
    if (req.method != "GET" && req.method != "HEAD") {
      return (pass);
    }

    ### Rules for Moodle and Totara sites ###
    # Moodle doesn't require Cookie to serve following assets. Remove Cookie header from request, so it will be looked up.
    if ( req.url ~ "^/altlogin/.+/.+\.(png|jpg|jpeg|gif|css|js|webp)$" ||
         req.url ~ "^/pix/.+\.(png|jpg|jpeg|gif)$" ||
         req.url ~ "^/theme/font.php" ||
         req.url ~ "^/theme/image.php" ||
         req.url ~ "^/theme/javascript.php" ||
         req.url ~ "^/theme/jquery.php" ||
         req.url ~ "^/theme/styles.php" ||
         req.url ~ "^/theme/yui" ||
         req.url ~ "^/lib/javascript.php/-1/" ||
         req.url ~ "^/lib/requirejs.php/-1/"
        )
    {
        set req.http.X-Long-TTL = "86400";
        unset req.http.Cookie;
        return(hash);
    }

    # Perform lookup for selected assets that we know are static but Moodle still needs a Cookie
    if(  req.url ~ "^/theme/.+\.(png|jpg|jpeg|gif|css|js|webp)" ||
         req.url ~ "^/lib/.+\.(png|jpg|jpeg|gif|css|js|webp)" ||
         req.url ~ "^/pluginfile.php/[0-9]+/course/overviewfiles/.+\.(?i)(png|jpg)$"
      )
    {
         # Set internal temporary header, based on which we will do things in vcl_backend_response
         set req.http.X-Long-TTL = "86400";
         return (hash);
    }

    # Serve requests to SCORM checknet.txt from varnish. Have to remove get parameters. Response body always contains "1"
    if ( req.url ~ "^/lib/yui/build/moodle-core-checknet/assets/checknet.txt" )
    {
        set req.url = regsub(req.url, "(.*)\?.*", "\1");
        unset req.http.Cookie; # Will go to hash anyway at the end of vcl_recv
        set req.http.X-Long-TTL = "86400";
        return(hash);
    }

    # Requests containing "Cookie" or "Authorization" headers will not be cached
    if (req.http.Authorization || req.http.Cookie) {
        return (pass);
    }

    # Almost everything in Moodle correctly serves Cache-Control headers, if
    # needed, which varnish will honor, but there are some which don't. Rather
    # than explicitly finding them all and listing them here we just fail safe
    # and don't cache unknown urls that get this far.
    return (pass);
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    # 
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.

    # We know these assest are static, let's set TTL >0 and allow client caching
    if ( beresp.http.Cache-Control && bereq.http.X-Long-TTL && beresp.ttl < std.duration(bereq.http.X-Long-TTL + "s", 1s) && !beresp.http.WWW-Authenticate )
    { # If max-age < defined in X-Long-TTL header
        set beresp.http.X-Orig-Pragma = beresp.http.Pragma; unset beresp.http.Pragma;
        set beresp.http.X-Orig-Cache-Control = beresp.http.Cache-Control;
        set beresp.http.Cache-Control = "public, max-age="+bereq.http.X-Long-TTL+", no-transform";
        set beresp.ttl = std.duration(bereq.http.X-Long-TTL + "s", 1s);
        unset bereq.http.X-Long-TTL;
    }
    else if( !beresp.http.Cache-Control && bereq.http.X-Long-TTL && !beresp.http.WWW-Authenticate ) {
        set beresp.http.X-Orig-Pragma = beresp.http.Pragma; unset beresp.http.Pragma;
        set beresp.http.Cache-Control = "public, max-age="+bereq.http.X-Long-TTL+", no-transform";
        set beresp.ttl = std.duration(bereq.http.X-Long-TTL + "s", 1s);
        unset bereq.http.X-Long-TTL;
    }
    else { # Don't touch headers if max-age > defined in X-Long-TTL header
        unset bereq.http.X-Long-TTL;
    }

    # Here we set X-Trace header, prepending it to X-Trace header received from backend. Useful for troubleshooting
    if(beresp.http.x-trace && !beresp.was_304) {
        set beresp.http.X-Trace = regsub(server.identity, "^([^.]+),?.*$", "\1")+"->"+regsub(beresp.backend.name, "^(.+)\((?:[0-9]{1,3}\.){3}([0-9]{1,3})\)","\1(\2)")+"->"+beresp.http.X-Trace;
    }
    else {
        set beresp.http.X-Trace = regsub(server.identity, "^([^.]+),?.*$", "\1")+"->"+regsub(beresp.backend.name, "^(.+)\((?:[0-9]{1,3}\.){3}([0-9]{1,3})\)","\1(\2)");
    }

    # Gzip JS, CSS is done at the ngnix level doing it here dosen't respect the no buffer requsets
    # if (beresp.http.content-type ~ "application/javascript.*" || beresp.http.content-type ~ "text") {
    #    set beresp.do_gzip = true;
    #}
}

sub vcl_deliver {

    # Revert back to original Cache-Control header before delivery to client
    if (resp.http.X-Orig-Cache-Control)
    {
        set resp.http.Cache-Control = resp.http.X-Orig-Cache-Control;
        unset resp.http.X-Orig-Cache-Control;
    }

    # Revert back to original Pragma header before delivery to client
    if (resp.http.X-Orig-Pragma)
    {
        set resp.http.Pragma = resp.http.X-Orig-Pragma;
        unset resp.http.X-Orig-Pragma;
    }

    # (Optional) X-Cache HTTP header will be added to responce, indicating whether object was retrieved from backend, or served from cache
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }

    # Set X-AuthOK header when totara/varnsih authentication succeeded
    if (req.http.X-AuthOK) {
        set resp.http.X-AuthOK = req.http.X-AuthOK;
    }

    # If desired "Via: 1.1 Varnish-v4" response header can be removed from response
    unset resp.http.Via;
    unset resp.http.Server;

    return(deliver);
}

sub vcl_backend_error {
    # More comprehensive varnish error page. Display time, instance hostname, host header, url for easier troubleshooting.
    set beresp.http.Content-Type = "text/html; charset=utf-8";
    set beresp.http.Retry-After = "5";
    synthetic( {"
  <!DOCTYPE html>
  <html>
    <head>
      <title>"} + beresp.status + " " + beresp.reason + {"</title>
    </head>
    <body>
      <h1>Error "} + beresp.status + " " + beresp.reason + {"</h1>
      <p>"} + beresp.reason + {"</p>
      <h3>Guru Meditation:</h3>
      <p>Time: "} + now + {"</p>
      <p>Node: "} + server.hostname + {"</p>
      <p>Host: "} + bereq.http.host + {"</p>
      <p>URL: "} + bereq.url + {"</p>
      <p>XID: "} + bereq.xid + {"</p>
      <hr>
      <p>Varnish cache server
    </body>
  </html>
  "} );
   return (deliver);
}

sub vcl_synth {

    #Redirect using '301 - Permanent Redirect', permanent redirect
    if (resp.status == 851) { 
        set resp.http.Location = req.http.x-redir;
        set resp.http.X-Varnish-Redirect = true;
        set resp.status = 301;
        return (deliver);
    }

    #Redirect using '302 - Found', temporary redirect
    if (resp.status == 852) { 
        set resp.http.Location = req.http.x-redir;
        set resp.http.X-Varnish-Redirect = true;
        set resp.status = 302;
        return (deliver);
    }

    #Redirect using '307 - Temporary Redirect', !GET&&!HEAD requests, dont change method on redirected requests
    if (resp.status == 857) { 
        set resp.http.Location = req.http.x-redir;
        set resp.http.X-Varnish-Redirect = true;
        set resp.status = 307;
        return (deliver);
    }

    #Respond with 403 - Forbidden
    if (resp.status == 863) {
        set resp.http.X-Varnish-Error = true;
        set resp.status = 403;
        return (deliver);
    }
}
EOF

# This code is stop apache2 which is installing in 18.04
  service=apache2
  if [ "$webServerType" = "nginx" ]; then
      if pgrep -x "$service" >/dev/null 
      then
            echo “Stop the $service!!!”
            systemctl stop $service
      else
            systemctl mask $service
      fi
  fi
  # Restart Varnish
  systemctl daemon-reload
  systemctl restart varnish

   if [ "$webServerType" = "nginx" ]; then
     # fpm config - overload this 
     cat <<EOF > /etc/php/${PhpVer}/fpm/pool.d/www.conf
[www]
user = www-data
group = www-data
listen = /run/php/php${PhpVer}-fpm.sock
listen.owner = www-data
listen.group = www-data
pm = static
pm.max_children = 32
pm.start_servers = 32
pm.max_requests = 300000
EOF

cat <<EOF > /etc/php/${PhpVer}/fpm/pool.d/backup.conf
[backup]
user = www-data
group = www-data
listen = /run/php/php${PhpVer}-fpm-backup.sock
listen.owner = www-data
listen.group = www-data
pm = static
pm.max_children = 16
pm.start_servers = 16
pm.max_requests = 300000
EOF

     # Restart fpm
     service php${PhpVer}-fpm restart
   fi

   if [ "$webServerType" = "apache" ]; then
      if [ "$htmlLocalCopySwitch" != "true" ]; then
        setup_moodle_mount_dependency_for_systemd_service apache2 || exit 1
      fi
        service apache2 restart
   fi

  echo "### Script End `date`###"
} 2>&1 | tee /tmp/setup.log
