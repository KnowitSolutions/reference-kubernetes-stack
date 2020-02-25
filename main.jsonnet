local keycloak = import 'login/keycloak.libsonnet';
local grafana = import 'monitoring/grafana.libsonnet';
local prometheus = import 'monitoring/prometheus.libsonnet';
local metadata = import 'templates/metadata.libsonnet';
local namespace = import 'templates/namespace.libsonnet';

function(
  keycloak_address='sso.local',
  grafana_address='grafana.local',
  grafana_client_secret='Regenerate me'
)
  local config = {
    keycloak: {
      namespace: 'login',
      external_address: keycloak_address,
      internal_address: 'keycloak.login',
    },
    prometheus: {
      namespace: 'monitoring',
    },
    grafana: {
      namespace: 'monitoring',
      external_address: grafana_address,
      oidc: {
        client_id: 'grafana',
        client_secret: grafana_client_secret,
      },
    },
  };

  [
    namespace.new() +
    metadata.new('login'),

    namespace.new() +
    metadata.new('monitoring'),
  ] +
  keycloak(config) +
  prometheus(config) +
  grafana(config)
