local initialize = import 'initialize.libsonnet';
local keycloak = import 'keycloak.libsonnet';

function(config)
  keycloak(config) +
  initialize(config)
