import os


class Configuration:
    def __init__(self):
        self.client_id = os.getenv('SPNAME')
        self.secret = os.getenv('SPPASSWORD')
        self.tenant_id = os.getenv('SPTENANT')
        self.subscription_id = os.getenv('SPSUBSCRIPTION')
        self.location = os.getenv('LOCATION', 'southcentralus')
        self.resource_group = os.getenv('RESOURCEGROUP')
        if self.resource_group is None:
            self.resource_group = 'azmdl-travis-' + os.getenv('TRAVIS_BUILD_NUMBER', 'manual')

    def is_valid(self):
        return None not in [self.client_id, self.secret, self.tenant_id, self.subscription_id]
