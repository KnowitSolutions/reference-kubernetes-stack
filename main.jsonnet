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
  cassandra_address,
  cassandra_port=9042,
  cassandra_username=null,
  cassandra_password=null,
  cassandra_tls=false,
  cassandra_tls_hostname_validation=true,
  cassandra_timeout='1s',

  postgres_address,
  postgres_port=5432,
  postgres_username,
  postgres_password,

  loki_keyspace='loki',
  promtail_log_type='cri',  // Valid choices: cri, docker, raw

  keycloak_address,
  keycloak_database='keycloak',
  keycloak_username='admin',
  keycloak_password='admin',

  grafana_address,
  grafana_client_secret='Regenerate me',

  kiali_address,
  kiali_client_secret='Regenerate me',

  jaeger_address,
  jaeger_keyspace='jaeger',
  jaeger_client_secret='Regenerate me',
)
  local cassandra = {
    address: cassandra_address,
    port: cassandra_port,
    username: cassandra_username,
    password: cassandra_password,
    tls: {
      enabled: cassandra_tls,
      hostname_validation: cassandra_tls_hostname_validation,
    },
    timeout: cassandra_timeout,
  };

  local postgres = {
    address: postgres_address,
    port: postgres_port,
    username: postgres_username,
    password: postgres_password,
  };

  local config = {
    loki: {
      namespace: 'monitoring',
      cassandra: cassandra { keyspace: loki_keyspace },
    },
    promtail: {
      namespace: 'monitoring',
      log_type: promtail_log_type,
    },
    kube_state_metrics: {
      namespace: 'monitoring',
    },
    keycloak: {
      namespace: 'login',
      postgres: postgres { database: keycloak_database },
      external_address: keycloak_address,
      internal_address: 'keycloak.login',
      admin: {
        username: keycloak_username,
        password: keycloak_password,
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
      cassandra: cassandra { keyspace: jaeger_keyspace },
      external_address: jaeger_address,
      oidc: {
        client_id: 'jaeger',
        client_secret: jaeger_client_secret,
      },
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
