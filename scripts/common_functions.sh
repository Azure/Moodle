#!/bin/bash

# Common functions definitions

function check_fileServerType_param
{
    local fileServerType=$1
    if [ "$fileServerType" != "gluster" -a "$fileServerType" != "azurefiles" ]; then
        echo "Invalid fileServerType ($fileServerType) given. Only 'gluster' or 'azurefiles' are allowed. Exiting"
        exit 1
    fi
}

function create_azure_files_moodle_share
{
    local storageAccountName=$1
    local storageAccountKey=$2
    local logFilePath=$3

    az storage share create \
        --name moodle \
        --account-name $storageAccountName \
        --account-key $storageAccountKey \
        --fail-on-exist >> $logFilePath
}

function setup_and_mount_azure_files_moodle_share
{
    local storageAccountName=$1
    local storageAccountKey=$2

    cat <<EOF > /etc/moodle_azure_files.credential
username=$storageAccountName
password=$storageAccountKey
EOF
    chmod 600 /etc/moodle_azure_files.credential
    
    grep "^//$storageAccountName.file.core.windows.net/moodle\s\s*/moodle\s\s*cifs" /etc/fstab
    if [ $? != "0" ]; then
        echo "//$storageAccountName.file.core.windows.net/moodle   /moodle cifs    credentials=/etc/moodle_azure_files.credential,uid=www-data,gid=www-data,nofail,vers=3.0,dir_mode=0755,file_mode=0644,serverino,mfsymlinks" >> /etc/fstab
    fi
    mkdir -p /moodle
    mount /moodle
}