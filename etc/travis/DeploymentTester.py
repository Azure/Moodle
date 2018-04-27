import sys
import time

from azure.mgmt.resource import ResourceManagementClient
from msrestazure.azure_active_directory import ServicePrincipalCredentials

from travis.Configuration import Configuration

DEPLOYMENT_NAME = 'azure-moodle-deployment-test'


class DeploymentTester:
    def __init__(self):
        self.config = Configuration()
        self.deployment = None

        self.credentials = None
        """:type : ServicePrincipalCredentials"""

        self.resource_client = None
        """:type : ResourceManagementClient"""

    def run(self):
        self.check_configuration()
        self.login()
        self.create_resource_group()
        self.validate()
        self.deploy()
        self.moodle_smoke_test()
        print('\n\nJob done!')

    def check_configuration(self):
        print('\nChecking configuration...')
        if not self.config.is_valid():
            print('No Azure deployment info given, skipping test deployment and exiting.')
            print('Further information: https://github.com/Azure/Moodle#automated-testing-travis-ci')
            sys.exit()
        print("(all check)")

    def login(self):
        print('\nLogging in...')
        self.credentials = ServicePrincipalCredentials(
            client_id=self.config.client_id,
            secret=self.config.secret,
            tenant=self.config.tenant_id,
        )
        self.resource_client = ResourceManagementClient(self.credentials, self.config.subscription_id)
        print("(logged in)")

    def create_resource_group(self):
        print('\nCreating group "{}" on "{}"...'.format(self.config.resource_group, self.config.location))
        self.resource_client.resource_groups.create_or_update(self.config.resource_group,
                                                              {'location': self.config.location})
        print('(created)')

    def validate(self):
        print('\nValidating template...')

        validation = self.resource_client.deployments.validate(self.config.resource_group,
                                                               self.config.deployment_name,
                                                               self.config.deployment_properties)
        if validation.error is not None:
            print("*** VALIDATION FAILED ***")
            print(validation.error.message)
            sys.exit(1)

        print("(valid)")

    def deploy(self):
        print('\nDeploying template, feel free to take a nap...')
        deployment = self.resource_client.deployments.create_or_update(self.config.resource_group,
                                                                       self.config.deployment_name,
                                                                       self.config.deployment_properties)
        """:type : msrestazure.azure_operation.AzureOperationPoller"""
        started = time.time()
        while not deployment.done():
            print('... after {} still "{}" ...'.format(self.elapsed(started), deployment.status()))
            deployment.wait(60)
        print("WAKE UP! After {} we finally got status {}.".format(self.elapsed(started), deployment.status()))

        print("Checking deployment response...")
        properties = deployment.result(0).properties
        if not properties.provisioning_state == 'Succeeded':
            print("*** DEPLOY FAILED ***")
            print('Provisioning state: ' + properties.provisioning_state)
            sys.exit(1)
        self.load_deployment_outputs(properties.outputs)
        print("(success)")

    def load_deployment_outputs(self, outputs):
        self.deployment = {}
        for key, value in outputs.items():
            self.deployment[key] = value['value']
            print("- Found: " + key)

    def moodle_smoke_test(self):
        pass

    def elapsed(self, since):
        elapsed = int(time.time() - since)
        elapsed = '{:02d}:{:02d}:{:02d}'.format(elapsed // 3600, (elapsed % 3600 // 60), elapsed % 60)
        return elapsed
