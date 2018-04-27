import json
import sys

from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.resource.resources.v2017_05_10.models import DeploymentMode
from msrestazure.azure_active_directory import ServicePrincipalCredentials

from travis.Configuration import Configuration


class DeploymentTester:
    ERROR_VALIDATION_FAILED = 1

    def __init__(self):
        self.config = Configuration()
        self.credentials = None

    def run(self):
        self.check_configuration()
        self.login()
        self.create_resource_group()
        self.validate()
        print('Job done!')

    def check_configuration(self):
        print('Checking configuration...')
        if not self.config.is_valid():
            print('No Azure deployment info given, skipping test deployment and exiting.')
            print('Further information: https://github.com/Azure/Moodle#automated-testing-travis-ci')
            sys.exit()

    def login(self):
        print('Logging in...')
        self.credentials = ServicePrincipalCredentials(
            client_id=self.config.client_id,
            secret=self.config.secret,
            tenant=self.config.tenant_id,
        )
        self.resource_client = ResourceManagementClient(self.credentials, self.config.subscription_id)

    def create_resource_group(self):
        print('Creating group "{}" on "{}"...'.format(self.config.resource_group, self.config.location))
        client = ResourceManagementClient(self.credentials, self.config.subscription_id)
        client.resource_groups.create_or_update(self.config.resource_group,
                                                {'location': self.config.location})

    def validate(self):
        print('Validating deployment...')
        with open('azuredeploy.json', 'r') as template_file_fd:
            template = json.load(template_file_fd)
        with open('azuredeploy.parameters.json', 'r') as template_file_fd:
            parameters = json.load(template_file_fd)
        parameters = parameters['parameters']

        properties = {
            'mode': DeploymentMode.incremental,
            'template': template,
            'parameters': parameters,
        }

        client = ResourceManagementClient(self.credentials, self.config.subscription_id)
        validation = client.deployments.validate(self.config.resource_group,
                                                 'azure-moodle-deployment-test',
                                                 properties)
        if validation.error is not None:
            print("*** VALIDATION FAILED ***")
            print(validation.error.message)
            sys.exit(DeploymentTester.ERROR_VALIDATION_FAILED)
