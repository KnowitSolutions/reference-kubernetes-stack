local grafana = import 'grafana/main.libsonnet';
local jaeger = import 'jaeger/main.libsonnet';
local keycloak = import 'keycloak/main.libsonnet';
local kiali = import 'kiali/main.libsonnet';
local kube_state_metrics = import 'kube-state-metrics/main.libsonnet';
local loki = import 'loki/main.libsonnet';
local promtail = import 'promtail/main.libsonnet';
local metadata = import 'templates/metadata.libsonnet';
local namespace = import 'templates/namespace.libsonnet';
local peerauthentication = import 'templates/peerauthentication.libsonnet';

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
    kube_state_metrics: {
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
    jaeger: {
      namespace: 'monitoring',
    },
  };

  [
    peerauthentication.new() +
    metadata.new('default', ns='istio-system') +
    peerauthentication.mtls(true),

    ns('login'),
    ns('monitoring'),
  ] +

  loki(config) +
  promtail(config) +
  kube_state_metrics(config) +
  keycloak(config) +
  grafana(config) +
  kiali(config) +
  jaeger(config)
