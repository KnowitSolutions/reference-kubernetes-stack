local initialize = import 'initialize.jsonnet';
local keycloak = import 'keycloak.jsonnet';

function(config)
  keycloak(config) +
  initialize(config)
