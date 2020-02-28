local keycloak = import 'login/keycloak.libsonnet';
local grafana = import 'monitoring/grafana.libsonnet';
local kiali = import 'monitoring/kiali.libsonnet';
local prometheus = import 'monitoring/prometheus.libsonnet';
local metadata = import 'templates/metadata.libsonnet';
local namespace = import 'templates/namespace.libsonnet';

local ns(name) =
  namespace.new() +
  metadata.new(name);

function(
  keycloak_address='sso.localhost',
  kiali_address='kiali.localhost',
  kiali_client_secret='Regenerate me',
  grafana_address='grafana.localhost',
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
    kiali: {
      namespace: 'monitoring',
      external_address: kiali_address,
      oidc: {
        client_id: 'kiali',
        client_secret: kiali_client_secret,
      },
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

  [ns('login'), ns('monitoring')] +
  keycloak(config) +
  kiali(config) +
  grafana(config)
