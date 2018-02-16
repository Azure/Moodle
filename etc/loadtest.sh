#!/bin/bash

function install_az_cli
{
    local az_repo=$(lsb_release -cs)
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $az_repo main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
    sudo apt-key adv --keyserver packages.microsoft.com --recv-keys 52E16F86FEE04B979B07E28DB02C46DF417A0893
    sudo apt-get install -y apt-transport-https
    sudo apt-get update && sudo apt-get install -y azure-cli
}

function check_if_logged_on_azure
{
    az account show --query id -o tsv > /dev/null 2>&1
    if [ $? != "0" ]; then
        echo "Not logged on to Azure. Run 'az login' first and make sure subscription is set to your desired one."
        return 1
    fi
}

function show_command_to_run
{
    echo "Running command: $*"
}

# BADBAD hard-coded Azure location. Parametrize this later.
LOCATION=southcentralus

function deploy_moodle_with_some_parameters_nowait
{
    check_if_logged_on_azure || return 1

    local resource_group=${1}
    local deployment_name=${2}
    local template_uri=${3}
    local parameters_template_file=${4}
    local web_vm_sku=${5}
    local db_server_type=${6}
    local web_server_type=${7}
    local file_server_type=${8}
    local ssh_pub_key=${9}

    local cmd="az group create --resource-group $resource_group --location $LOCATION"
    show_command_to_run $cmd
    eval $cmd || return 1

    local cmd="az group deployment create --resource-group $resource_group --name $deployment_name --no-wait --template-uri $template_uri --parameters @$parameters_template_file autoscaleVmSku=$web_vm_sku dbServerType=$db_server_type webServerType=$web_server_type fileServerType=$file_server_type sshPublicKey='$ssh_pub_key'"
    show_command_to_run $cmd
    eval $cmd
}

function delete_resource_group
{
    check_if_logged_on_azure || return 1

    local resource_group=${1}
    local cmd="az group delete --resource-group $resource_group"
    show_command_to_run $cmd
    eval $cmd
}

function install_moosh
{
    sudo apt update
    sudo apt install -y composer
    cd ~
    git clone git://github.com/tmuras/moosh.git
    cd moosh
    composer install
    mkdir -p ~/bin
    ln -s $PWD/moosh.php ~/bin/moosh
}

function install_moosh_on_remote_host
{
    local ssh_dest=${1}   # E.g., azureadmin@10.2.3.4
    local port=${2:-22}       # E.g., 2222

    local cmd="ssh -p $port $ssh_dest 'wget https://raw.githubusercontent.com/Azure/Moodle/hs-loadtest/etc/loadtest.sh; source loadtest.sh; install_moosh'"
    show_command_to_run $cmd
    eval $cmd
}
