local keycloak = import 'login/keycloak.libsonnet';
local grafana = import 'monitoring/grafana.libsonnet';
local kiali = import 'monitoring/kiali.libsonnet';
local loki = import 'monitoring/loki.libsonnet';
local promtail = import 'monitoring/promtail.libsonnet';
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
  grafana_client_secret='Regenerate me',
)
  local config = {
    loki: {
      namespace: 'monitoring',
    },
    promtail: {
      namespace: 'monitoring',
    },
    keycloak: {
      namespace: 'login',
      external_address: keycloak_address,
      internal_address: 'keycloak.login',
    },
    grafana: {
      namespace: 'monitoring',
      external_address: grafana_address,
      oidc: {
        client_id: 'grafana',
        client_secret: grafana_client_secret,
      },
    },
    kiali: {
      namespace: 'monitoring',
      external_address: kiali_address,
      oidc: {
        client_id: 'kiali',
        client_secret: kiali_client_secret,
      },
    },
  };

  [ns('login'), ns('monitoring')] +
  loki(config) +
  promtail(config) +
  keycloak(config) +
  grafana(config) +
  kiali(config)
