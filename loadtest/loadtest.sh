#!/bin/bash

# This is not fully tested. Just documenting what's needed.
function install_java_and_jmeter
{
    sudo apt update || return 1
    sudo apt install -y openjdk-8-jdk || return 1

    wget -O apache-jmeter-4.0.tgz http://www-us.apache.org/dist/jmeter/binaries/apache-jmeter-4.0.tgz || return 1
    tar xfz apache-jmeter-4.0.tgz -C ~
    mkdir -p ~/bin
    ln -s ~/apache-jmeter-4.0/bin/jmeter ~/bin/jmeter
    rm apache-jmeter-4.0.tgz

    wget -O mysql-connector-java-5.1.45.tar.gz https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.45.tar.gz || return 1
    tar xfz mysql-connector-java-5.1.45.tar.gz
    mv mysql-connector-java-5.1.45/mysql-connector-java-5.1.45-bin.jar ~/apache-jmeter-4.0/lib
    rm -rf mysql-connector-java-5.1.45*

    wget -O postgres-42.2.1.jar https://jdbc.postgresql.org/download/postgresql-42.2.1.jar || return 1
    mv postgres-42.2.1.jar ~/apache-jmeter-4.0/lib

    # Have to have jmeter plugins manager and have it download the needed plugins in advance...
    wget -O jmeter-plugins-manager-0.19.jar http://search.maven.org/remotecontent?filepath=kg/apc/jmeter-plugins-manager/0.19/jmeter-plugins-manager-0.19.jar || return 1
    mv jmeter-plugins-manager-0.19.jar ~/apache-jmeter-4.0/lib/ext

    wget -O cmdrunner-2.0.jar http://search.maven.org/remotecontent?filepath=kg/apc/cmdrunner/2.0/cmdrunner-2.0.jar || return 1
    mv cmdrunner-2.0.jar ~/apache-jmeter-4.0/lib
    java -cp ~/apache-jmeter-4.0/lib/ext/jmeter-plugins-manager-0.19.jar org.jmeterplugins.repository.PluginManagerCMDInstaller
    # TODO Hard-coded .jmx file here. Do this for each individual .jmx file
    wget -O tmp-for-plugin-install.jmx https://raw.githubusercontent.com/Azure/Moodle/master/loadtest/simple-test-1.jmx || return 1
    ~/apache-jmeter-4.0/bin/PluginsManagerCMD.sh install-for-jmx tmp-for-plugin-install.jmx
    rm tmp-for-plugin-install.jmx
}

function install_az_cli
{
    local az_repo=$(lsb_release -cs)
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $az_repo main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
    sudo apt-key adv --keyserver packages.microsoft.com --recv-keys 52E16F86FEE04B979B07E28DB02C46DF417A0893
    sudo apt-get install -y apt-transport-https || return 1
    sudo apt-get update && sudo apt-get install -y azure-cli || return 1
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

function check_db_sku_params
{
    local dtu=${1}
    local size=${2}

    if [ "$dtu" != 100 -a "$dtu" != 200 -a "$dtu" != 400 -a "$dtu" != 800 ]; then
        echo "Invalid DTU ($dtu). Only allowed are 100, 200, 400, 800."
        return 1
    fi
    if [ "$size" != 125 ] && [ "$size" != 250 ] && [ "$size" != 375 ] && [ "$size" != 500 ] && [ "$size" != 625 ] && [ "$size" != 750 ] && [ "$size" != 875 ] && [ "$size" 1000 ]; then
        echo "Invalid DB size ($size). Only allowed are 125, 250, 375, ... 875, 1000."
        return 1
    fi
}

function get_db_sku_name
{
    local db_server_type=${1}
    local db_dtu=${2}

    if [ "$db_server_type" = mysql ]; then
        echo "MYSQLS${db_dtu}"
    elif [ "$db_server_type" = postgres ]; then
        echo "PGSQLS${db_dtu}"
    else
        echo "Invalid DB type ($db_server_type). Only mysql or postgres are allowed"
        return 1
    fi
}

# TODO hard-coded Azure location in global variable. Parametrize this later.
MOODLE_RG_LOCATION=southcentralus

function deploy_moodle_with_some_parameters
{
    check_if_logged_on_azure || return 1

    local resource_group=${1}   # Azure resource group where templates will be deployed
    local template_url=${2}     # Github URL of the top template to deploy
    local parameters_template_file=${3} # Local parameter template file
    local web_server_type=${4}  # E.g., apache or nginx
    local web_vm_sku=${5}       # E.g., Standard_DS2_v2
    local db_server_type=${6}   # E.g., mysql or postgres
    local db_dtu=${7}           # 100, 200, 400, 800 only
    local db_size=${8}          # 125, 250, 375, 500, 625, 750, 875. 1000 only
    local file_server_type=${9} # E.g., nfs or gluster
    local file_server_disk_count=${10}  # 2, 3, 4
    local file_server_disk_size=${11}   # in GB
    local redis_cache=${12}     # Redis cache choice. Currently 'true' or 'false' only.
    local ssh_pub_key=${13}     # Your ssh authorized_keys content
    local no_wait_flag=${14}    # Must be "--no-wait" to be passed to az

    check_db_sku_params $db_dtu $db_size || return 1
    local db_sku_name=$(get_db_sku_name $db_server_type $db_dtu) || return 1
    local db_size_mb=$(($db_size * 1024))

    local cmd="az group create --resource-group $resource_group --location $MOODLE_RG_LOCATION"
    show_command_to_run $cmd
    eval $cmd || return 1

    local deployment_name="${resource_group}-deployment"
    local cmd="az group deployment create --resource-group $resource_group --name $deployment_name $no_wait_flag --template-uri $template_url --parameters @$parameters_template_file webServerType=$web_server_type autoscaleVmSku=$web_vm_sku dbServerType=$db_server_type skuCapacityDTU=$db_dtu skuName=$db_sku_name skuSizeMB=$db_size_mb fileServerType=$file_server_type fileServerDiskCount=$file_server_disk_count fileServerDiskSize=$file_server_disk_size redisDeploySwitch=$redis_cache sshPublicKey='$ssh_pub_key'"
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
    sudo apt update || return 1
    sudo apt install -y composer || return 1
    cd ~
    git clone git://github.com/tmuras/moosh.git || return 1
    cd moosh
    composer install || sleep 30 && composer install || sleep 30 && composer install || return 1
    mkdir -p ~/bin
    ln -s $PWD/moosh.php ~/bin/moosh
}

MOODLE_PATH=/moodle/html/moodle

function delete_course
{
    local course_id=${1}

    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-delete $course_id
}

function create_course
{
    local course_id=${1}

    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-create --idnumber=$course_id empty@test.course
}

function restore_course_from_url
{
    local url=${1}

    wget $url -O backup_to_restore.mbz
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-restore backup_to_restore.mbz 1
}

function create_2000_test_users_and_enroll_them_in_course
{
    local course_id=${1}
    local password=${2}

    # TODO ugly...
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH user-create -p $password m_azuretestuser_{1..200}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH user-create -p $password m_azuretestuser_{201..400}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH user-create -p $password m_azuretestuser_{401..600}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH user-create -p $password m_azuretestuser_{601..800}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH user-create -p $password m_azuretestuser_{801..1000}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH user-create -p $password m_azuretestuser_{1001..1200}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH user-create -p $password m_azuretestuser_{1201..1400}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH user-create -p $password m_azuretestuser_{1401..1600}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH user-create -p $password m_azuretestuser_{1601..1800}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH user-create -p $password m_azuretestuser_{1801..2000}

    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-enrol $course_id m_azuretestuser_{1..200}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-enrol $course_id m_azuretestuser_{201..400}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-enrol $course_id m_azuretestuser_{401..600}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-enrol $course_id m_azuretestuser_{601..800}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-enrol $course_id m_azuretestuser_{801..1000}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-enrol $course_id m_azuretestuser_{1001..1200}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-enrol $course_id m_azuretestuser_{1201..1400}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-enrol $course_id m_azuretestuser_{1401..1600}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-enrol $course_id m_azuretestuser_{1601..1800}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-enrol $course_id m_azuretestuser_{1801..2000}
}

function hide_course_overview_block_for_jmeter_test
{
    # "myoverview" is the registered name of the "Course overview" block
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH block-manage hide myoverview
}

# TODO hard-coded values...
LOADTEST_BASE_URI=https://raw.githubusercontent.com/Azure/Moodle/master/loadtest
MOODLE_TEST_USER_PASSWORD='testUserP@$$w0rd'

function setup_test_course_and_users
{
    install_moosh
    # TODO hard-coded test course backup location
    restore_course_from_url $LOADTEST_BASE_URI/moodle-on-azure-test-course-1.mbz
    local course_id=2  # TODO Fix this hard-coded course id #. Should be retrieved from the previous restore_course_from_url output
    local password=$MOODLE_TEST_USER_PASSWORD   # TODO parameterize
    create_2000_test_users_and_enroll_them_in_course $course_id $password
    hide_course_overview_block_for_jmeter_test
}

function run_cmd_on_remote_host
{
    local func_cmd=${1}   # E.g., install_moosh or 'delete_course 2'
    local ssh_dest=${2}   # E.g., azureadmin@10.2.3.4
    local port=${3:-22}   # E.g., 2222

    local cmd="ssh -o 'StrictHostKeyChecking no' -p $port $ssh_dest 'wget $LOADTEST_BASE_URI/loadtest.sh -O loadtest.sh; source loadtest.sh; $func_cmd'"
    show_command_to_run $cmd
    eval $cmd
}

function run_simple_test_1_on_resource_group
{
    local resource_group=${1}       # Azure resource group where Moodle templates were deployed
    local test_threads_count=${2}   # E.g., 400, 800, ...
    local test_rampup_time_sec=${3} # E.g., 900 (should be long enough for # threads above)
    local test_run_time_sec=${4}    # E.g., 3600 for 1 hour
    local setup_test_course_users_flag=${5} # Run setup_test_course_and_users on moodle_host if nonzero

    sudo apt update; sudo apt install -y jq
    local deployment="${resource_group}-deployment"
    local output=$(az group deployment show -g $resource_group -n $deployment)
    local moodle_host=$(echo $output | jq -r .properties.outputs.siteURL.value)
    local db_host=$(echo $output | jq -r .properties.outputs.databaseDNS.value)
    local moodle_db_user=$(echo $output | jq -r .properties.outputs.moodleDbUsername.value)
    local moodle_db_pass=$(echo $output | jq -r .properties.outputs.moodleDbPassword.value)
    local moodle_user_pass=$MOODLE_TEST_USER_PASSWORD    # TODO parameterize

    if [ -n "$setup_test_course_users_flag" ]; then
        local moodle_controller_ip=$(echo $output | jq -r .properties.outputs.controllerInstanceIP.value)
        run_cmd_on_remote_host setup_test_course_and_users azureadmin@${moodle_controller_ip}
    fi

    mkdir -p test_outputs

    local prefix="test_outputs/simple_test_1_$(date +%Y%m%d%H%M%S)"
    echo $output | jq . > ${prefix}.deployment.json

    export JVM_ARGS="-Xms1024m -Xmx4096m"
    local cmd="jmeter -n -t simple-test-1.jmx -l ${prefix}.jmeter.results.txt -j ${prefix}.jmeter.log -e -o ${prefix}.jmeter.report -Jhost=${moodle_host} -Jdb_host=${db_host} -Jdb_user=${moodle_db_user} '-Jdb_pass=${moodle_db_pass}' '-Jmoodle_user_pass=${moodle_user_pass}' -Jthreads=${test_threads_count} -Jrampup=${test_rampup_time_sec} -Jruntime=${test_run_time_sec}"
    show_command_to_run $cmd
    eval $cmd
}

function deallocate_services_in_resource_group
{
    local rg=${1}

    # Deallocate VMSS's
    local scalesets=$(az vmss list -g $rg --query [].name -o tsv)
    for scaleset in $scalesets; do
        local cmd="az vmss deallocate -g $rg --name $scaleset"
        show_command_to_run $cmd
        eval $cmd
    done

    # Deallocate VMs
    local cmd="az vm deallocate --ids $(az vm list -g $rg --query [].id -o tsv)"
    show_command_to_run $cmd
    eval $cmd

    # Stopping DBs and redis cache is currently not possible on Azure.
}

function deploy_run_test1_teardown
{
    local resource_group=${1}
    local location=${2}
    local template_url=${3}
    local parameters_template_file=${4}
    local web_server_type=${5}
    local web_vm_sku=${6}
    local db_server_type=${7}
    local db_dtu=${8}
    local db_size=${9}
    local file_server_type=${10}
    local file_server_disk_count=${11}
    local file_server_disk_size=${12}
    local redis_cache=${13}
    local ssh_pub_key=${14}
    local test_threads_count=${15}
    local test_rampup_time_sec=${16}
    local test_run_time_sec=${17}
    local delete_resource_group_flag=${18}  # Any non-empty string is considered true

    MOODLE_RG_LOCATION=$location
    deploy_moodle_with_some_parameters $resource_group $template_url $parameters_template_file $web_server_type $web_vm_sku $db_server_type $db_dtu $db_size $file_server_type $file_server_disk_count $file_server_disk_size $redis_cache "$ssh_pub_key" || return 1
    run_simple_test_1_on_resource_group $resource_group $test_threads_count $test_rampup_time_sec $test_run_time_sec 1 || return 1
    if [ -n "$delete_resource_group_flag" ]; then
        az group delete -g $resource_group -y
    else
        deallocate_services_in_resource_group $resource_group
    fi
}

function check_ssh_agent_and_added_key
{
    ssh-add -l
    if [ $? != "0" ]; then
        echo "No ssh key added to ssh-agent or no ssh-agent is running. Make sure to run ssh-agent (eval `ssh-agent`) and add the correct ssh key (usually just ssh-add will do), so that remote commands execution through ssh doesn't prompt for interactive password."
        return 1
    fi
}

function run_load_test_example
{
    check_ssh_agent_and_added_key || return 1

    deploy_run_test1_teardown ltest6 southcentralus https://raw.githubusercontent.com/Azure/Moodle/master/azuredeploy.json azuredeploy.parameters.loadtest.defaults.json apache Standard_DS2_v2 mysql 200 125 nfs 2 128 false "$(cat ~/.ssh/authorized_keys)" 1600 4800 18000
}
