import json
import os
import time

from azure.mgmt.resource.resources.v2017_05_10.models import DeploymentMode


class Configuration:
    def __init__(self):
        self.deployment_name = 'azuredeploy'

        self.client_id = os.getenv('SPNAME')
        self.secret = os.getenv('SPPASSWORD')
        self.tenant_id = os.getenv('SPTENANT')
        self.subscription_id = os.getenv('SPSUBSCRIPTION')
        self.location = os.getenv('LOCATION', 'southcentralus')

        self.ssh_key = os.getenv('SPSSHKEY')
        if self.ssh_key is None:
            with open('azure_moodle_id_rsa.pub', 'r') as sshkey_fd:
                self.ssh_key = sshkey_fd.read()

        self.resource_group = os.getenv('RESOURCEGROUP')
        if self.resource_group is None:
            self.resource_group = 'azmdl-travis-' + os.getenv('TRAVIS_BUILD_NUMBER', 'manual-{}'.format(time.time()))

        self.deployment_properties = self.generate_properties()

    def generate_properties(self):
        with open('azuredeploy.json', 'r') as template_fd:
            template = json.load(template_fd)

        with open('azuredeploy.parameters.json', 'r') as parameters_fd:
            parameters = json.load(parameters_fd)
        parameters = parameters['parameters']
        parameters['sshPublicKey']['value'] = self.ssh_key

        return {
            'mode': DeploymentMode.incremental,
            'template': template,
            'parameters': parameters,
        }

    def is_valid(self):
        valid = True
        for key, value in vars(self).items():
            if value is None:
                valid = False
                print('(missing configuration for {})'.format(key))
        return valid
