import sys

from azure.mgmt.resource import ResourceManagementClient
from msrestazure.azure_active_directory import ServicePrincipalCredentials

from travis.Configuration import Configuration


class DeploymentTester:
    def __init__(self):
        self.config = Configuration()
        self.credentials = None

    def run(self):
        self.check_configuration()
        self.login()
        self.create_resource_group()
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

    def create_resource_group(self):
        print('Creating group "{}" on "{}"...'.format(self.config.resource_group, self.config.location))
        client = ResourceManagementClient(self.credentials, self.config.subscription_id)
        client.resource_groups.create_or_update(self.config.resource_group, {'location': self.config.location})
