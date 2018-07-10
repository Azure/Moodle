#!/bin/bash

LINK_PATH=$1        # E.g, /moodle
LINK_DEST=$2        # E.g,./data
SERVER_NAME=$3      # E.g., aks-test.westus2.cloudapp.azure.com
HTML_SRC_ROOT=$4    # E.g. /moodle/html/moodle
SSL_CERT_PATH=$5    # E.g., /moodle/certs/nginx.crt
SSL_KEY_PATH=$6     # E.g., /moodle/certs/nginx.key

service apache2 stop
a2enmod ssl
a2enmod php

rm -f /etc/apache2/sites-enabled/000-default.conf

if [ "$LINK_DEST" != "$LINK_PATH" ]; then
    ln -s $LINK_DEST $LINK_PATH
fi

sleep $(($RANDOM%30))   # Randomization to reduce contention
rsync -av --delete $HTML_SRC_ROOT /var/www/html

APACHE_DOC_ROOT=/var/www/html/$(basename $HTML_SRC_ROOT)

cat <<EOF > /etc/apache2/sites-enabled/azlamp.conf
<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        ServerName $SERVER_NAME

        ServerAdmin webmaster@$SERVER_NAME
        DocumentRoot $APACHE_DOC_ROOT

        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined

        SSLEngine on

        SSLCertificateFile      $SSL_CERT_PATH
        SSLCertificateKeyFile   $SSL_KEY_PATH

        <FilesMatch "\.(cgi|shtml|phtml|php)$">
            SSLOptions +StdEnvVars
        </FilesMatch>
        <Directory /usr/lib/cgi-bin>
            SSLOptions +StdEnvVars
        </Directory>
    </VirtualHost>
</IfModule>
EOF

service apache2 start

# Periodically check the timestamps and sync when they differ
sleep $(($RANDOM%60))   # Initial randomization to reduce contention

while true; do
    SERVER_TIMESTAMP_FULLPATH=$(ls $HTML_SRC_ROOT/.last_modified_time*)
    LOCAL_TIMESTAMP_FULLPATH=$APACHE_DOC_ROOT/$(basename $SERVER_TIMESTAMP_FULLPATH)

    if [ -f "$SERVER_TIMESTAMP_FULLPATH" ]; then
        SERVER_TIMESTAMP=$(cat $SERVER_TIMESTAMP_FULLPATH)
        if [ -f "$LOCAL_TIMESTAMP_FULLPATH" ]; then
            LOCAL_TIMESTAMP=$(cat $LOCAL_TIMESTAMP_FULLPATH)
        else
            echo "Local timestamp file ($LOCAL_TIMESTAMP_FULLPATH) does not exist. Probably first time syncing? Continuing to sync."
        fi
        if [ "$SERVER_TIMESTAMP" != "$LOCAL_TIMESTAMP" ]; then
            echo "Server time stamp ($SERVER_TIMESTAMP) is different from local time stamp ($LOCAL_TIMESTAMP). Start syncing (as of $(date +%Y%m%d%H%M%S))..."
            rsync -av --delete $HTML_SRC_ROOT /var/www/html
        fi
    else
        echo "Remote timestamp file ($SERVER_TIMESTAMP_FULLPATH) does not exist. Is $LINK_PATH mounted? Retrying in 1 minute"
    fi

    sleep 60
done
