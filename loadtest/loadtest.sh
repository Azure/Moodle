#!/bin/bash

function install_az_cli
{
    local az_repo=$(lsb_release -cs)
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $az_repo main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
    sudo apt-key adv --keyserver packages.microsoft.com --recv-keys 52E16F86FEE04B979B07E28DB02C46DF417A0893
    sudo apt-get install -y apt-transport-https
    sudo apt-get update && sudo apt-get install -y azure-cli
}

function install_package_if_not_installed
{
    local pkg=${1}
    dpkg -s $pkg > /dev/null 2>&1
    if [ $? != "0" ]; then
        sudo apt install -y $pkg
    fi
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

# TODO hard-coded Azure location. Parametrize this later.
LOCATION=southcentralus

function deploy_moodle_with_some_parameters_nowait
{
    check_if_logged_on_azure || return 1

    local resource_group=${1}   # Azure resource group where templates will be deployed
    local template_uri=${2}     # Github URL of the top template to deploy
    local parameters_template_file=${3} # Local parameter template file
    local web_vm_sku=${4}       # E.g., Standard_DS2_v2
    local db_server_type=${5}   # E.g., mysql or postgres
    local web_server_type=${6}  # E.g., apache or nginx
    local file_server_type=${7} # E.g., nfs or gluster
    local ssh_pub_key=${8}      # Your ssh authorized_keys content

    local cmd="az group create --resource-group $resource_group --location $LOCATION"
    show_command_to_run $cmd
    eval $cmd || return 1

    local deployment_name="${resource_group}-deployment"
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

function create_1000_test_users_and_enroll_them_in_course
{
    local course_id=${1}
    local password=${2}

    # TODO ugly...
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH user-create -p $password m_azuretestuser_{1..200}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH user-create -p $password m_azuretestuser_{201..400}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH user-create -p $password m_azuretestuser_{401..600}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH user-create -p $password m_azuretestuser_{601..800}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH user-create -p $password m_azuretestuser_{801..1000}

    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-enrol $course_id m_azuretestuser_{1..200}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-enrol $course_id m_azuretestuser_{201..400}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-enrol $course_id m_azuretestuser_{401..600}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-enrol $course_id m_azuretestuser_{601..800}
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH course-enrol $course_id m_azuretestuser_{801..1000}
}

function hide_course_overview_block_for_jmeter_test
{
    # "myoverview" is the registered name of the "Course overview" block
    sudo -u www-data ~/bin/moosh --moodle-path=$MOODLE_PATH block-manage hide myoverview
}

# TODO hard-coded values...
LOADTEST_BASE_URI=https://raw.githubusercontent.com/Azure/Moodle/hs-loadtest/loadtest
MOODLE_TEST_USER_PASSWORD='testUserP@$$w0rd'

function setup_test_course_and_users
{
    install_moosh
    # TODO hard-coded test course backup location
    restore_course_from_url $LOADTEST_BASE_URI/moodle-on-azure-test-course-1.mbz
    local course_id=2  # TODO Fix this hard-coded course id #. Should be retrieved from the previous restore_course_from_url output
    local password=$MOODLE_TEST_USER_PASSWORD   # TODO parameterize
    create_1000_test_users_and_enroll_them_in_course $course_id $password
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

    install_package_if_not_installed jq
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
    local cmd="jmeter -n -t simple-test-1.jmx -l ${prefix}.jmeter.results.txt -j ${prefix}.jmeter.log -o ${prefix}.jmeter.report -Jhost=${moodle_host} -Jdb_host=${db_host} -Jdb_user=${moodle_db_user} '-Jdb_pass=${moodle_db_pass}' '-Jmoodle_user_pass=${moodle_user_pass}' -Jthreads=${test_threads_count} -Jrampup=${test_rampup_time_sec} -Jruntime=${test_run_time_sec}"
    show_command_to_run $cmd
    eval $cmd
}
