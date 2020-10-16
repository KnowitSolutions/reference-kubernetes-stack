local cassandra = import 'cassandra/main.libsonnet';
local grafana = import 'grafana/main.libsonnet';
local istio_oidc = import 'istio-oidc/deployment/main.jsonnet';
local jaeger = import 'jaeger/main.libsonnet';
local keycloak = import 'keycloak/main.libsonnet';
local kiali = import 'kiali/main.libsonnet';
local kube_state_metrics = import 'kube-state-metrics/main.libsonnet';
local loki = import 'loki/main.libsonnet';
local mssql = import 'mssql/main.libsonnet';
local postgres = import 'postgres/main.libsonnet';
local promtail = import 'promtail/main.libsonnet';
local issuer = import 'templates/issuer.libsonnet';
local metadata = import 'templates/metadata.libsonnet';
local namespace = import 'templates/namespace.libsonnet';
local peerauthentication = import 'templates/peerauthentication.libsonnet';
local pod = import 'templates/pod.libsonnet';

local ns(name) =
  namespace.new() +
  metadata.new(name);

function(
  namespace='base',
  node_selector=null,
  node_tolerations=null,

  ingress_tls=false,
  lets_encrypt_email=null,

  cassandra_replicas=3,
  cassandra_vip='10.0.10.1',
  cassandra_address=null,
  cassandra_port=9042,
  cassandra_username=null,
  cassandra_password=null,
  cassandra_tls=false,
  cassandra_tls_hostname_validation=true,
  cassandra_timeout='10s',  // TODO: Why is this so high? 1s ought to be enough

  postgres_vip='10.0.10.2',
  postgres_address=null,
  postgres_port=5432,
  postgres_username=null,
  postgres_password=null,
  postgres_tls=false,
  postgres_tls_hostname_validation=true,

  mssql_vip='10.0.10.3',
  mssql_address=null,
  mssql_port=1433,
  mssql_username=null,
  mssql_password=null,
  mssql_tls=false,
  mssql_tls_hostname_validation=true,

  // TODO: loki_replicas=2,
  loki_keyspace='loki',
  promtail_log_type='cri',  // Valid choices: cri, docker, raw

  keycloak_replicas=2,
  keycloak_address,
  keycloak_database='keycloak',
  keycloak_username='admin',
  keycloak_password='admin',

  istio_oidc_replicas=2,

  grafana_replicas=2,
  grafana_address,
  grafana_database='grafana',
  grafana_client_secret='Regenerate me',

  kiali_replicas=2,
  kiali_address,
  kiali_client_secret='Regenerate me',

  jaeger_replicas=2,
  jaeger_address,
  jaeger_keyspace='jaeger',
  jaeger_client_secret='Regenerate me',
)
  local affinity = if node_selector != null then pod.new_affinity(node_selector) else {};
  local tolerations = if node_tolerations != null then pod.new_tolerations(node_tolerations) else [];

  local cassandra_connection = {
    assert if cassandra_address == null then
      cassandra_address == null &&
      cassandra_port == 9042 &&
      cassandra_username == null &&
      cassandra_password == null &&
      cassandra_tls == false
    else true : 'Cannot override Cassandra connection details when using bundled instance',

    assert if cassandra_address != null then
      cassandra_replicas == 3
    else true : 'Cannot override Cassandra settings when using external instance',

    address: if cassandra_address == null then 'cassandra.%s' % namespace else cassandra_vip,
    port: cassandra_port,
    username: cassandra_username,
    password: cassandra_password,
    tls: {
      enabled: cassandra_tls,
      hostname_validation: cassandra_tls_hostname_validation,
    },
    timeout: cassandra_timeout,
  };

  local postgres_connection = {
    assert if postgres_address != null then
      postgres_username != null &&
      postgres_password != null
    else true : 'Missing Postgres credentials',

    enabled: postgres_address != null,
    address: postgres_vip,
    port: postgres_port,
    username: postgres_username,
    password: postgres_password,
    tls: {
      enabled: postgres_tls,
      hostname_validation: postgres_tls_hostname_validation,
    },
  };

  local mssql_connection = {
    assert if mssql_address != null then
      mssql_username != null &&
      mssql_password != null
    else true : 'Missing SQL Server credentials',

    enabled: mssql_address != null,
    address: mssql_vip,
    port: mssql_port,
    username: mssql_username,
    password: mssql_password,
    tls: {
      enabled: mssql_tls,
      hostname_validation: mssql_tls_hostname_validation,
    },
  };

  local tls_config = {
    enabled: ingress_tls,
    acme: lets_encrypt_email != null,
  };

  local config = {
    cassandra: {
      bundled: cassandra_address == null,
      namespace: namespace,
      replicas: cassandra_replicas,
      vip: {
        enabled: cassandra_address != null,
        internal_address: cassandra_vip,
        external_address: cassandra_address,
        port: cassandra_port,
      },
      affinity: affinity,
      tolerations: tolerations,
    },
    postgres: {
      namespace: namespace,
      vip: {
        enabled: postgres_address != null,
        internal_address: postgres_vip,
        external_address: postgres_address,
        port: postgres_port,
      },
    },
    mssql: {
      namespace: namespace,
      vip: {
        enabled: mssql_address != null,
        internal_address: mssql_vip,
        external_address: mssql_address,
        port: mssql_port,
      },
    },
    loki: {
      namespace: namespace,
      cassandra: cassandra_connection { keyspace: loki_keyspace },
      affinity: affinity,
      tolerations: tolerations,
    },
    promtail: {
      namespace: namespace,
      log_type: promtail_log_type,
      affinity: affinity,
      tolerations: tolerations,
    },
    kube_state_metrics: {
      namespace: namespace,
      affinity: affinity,
      tolerations: tolerations,
    },
    keycloak: {
      namespace: namespace,
      replicas: keycloak_replicas,
      storage:
        if postgres_address != null then 'postgres'
        else if mssql_address != null then 'mssql'
        else error 'Missing Postgres/SQL Server connection details',
      postgres: postgres_connection { database: keycloak_database },
      mssql: mssql_connection { database: keycloak_database },
      external_protocol: if self.tls.enabled then 'https' else 'http',
      external_address: keycloak_address,
      internal_address: 'keycloak.%s' % namespace,
      tls: tls_config,
      admin: {
        username: keycloak_username,
        password: keycloak_password,
      },
      affinity: affinity,
      tolerations: tolerations,
    },
    grafana: {
      assert grafana_replicas == 1 || self.postgres.enabled
             : 'Grafana high availability in unavailable without Postgres',

      namespace: namespace,
      replicas: grafana_replicas,
      external_protocol: if self.tls.enabled then 'https' else 'http',
      external_address: grafana_address,
      tls: tls_config,
      postgres: postgres_connection { database: grafana_database },
      oidc: {
        client_id: 'grafana',
        client_secret: grafana_client_secret,
      },
      affinity: affinity,
      tolerations: tolerations,
    },
    kiali: {
      namespace: namespace,
      replicas: kiali_replicas,
      external_protocol: if self.tls.enabled then 'https' else 'http',
      external_address: kiali_address,
      tls: tls_config,
      oidc: {
        client_id: 'kiali',
        client_secret: kiali_client_secret,
      },
      affinity: affinity,
      tolerations: tolerations,
    },
    jaeger: {
      namespace: namespace,
      replicas: jaeger_replicas,
      cassandra: cassandra_connection { keyspace: jaeger_keyspace },
      external_protocol: if self.tls.enabled then 'https' else 'http',
      external_address: jaeger_address,
      tls: tls_config,
      oidc: {
        client_id: 'jaeger',
        client_secret: jaeger_client_secret,
      },
      affinity: affinity,
      tolerations: tolerations,
    },
  };

  [
    peerauthentication.new() +
    metadata.new('default', ns='istio-system') +
    peerauthentication.mtls(true),

    ns(namespace),
  ] +

  (if lets_encrypt_email != null then [
     issuer.new(email=lets_encrypt_email) +
     issuer.http_solver(),
   ] else []) +

  cassandra(config) +
  postgres(config) +
  mssql(config) +
  loki(config) +
  promtail(config) +
  kube_state_metrics(config) +
  keycloak(config) +
  istio_oidc(
    NAMESPACE=namespace,
    VERSION='master',
    REPLICAS=istio_oidc_replicas,
    AFFINITY=affinity,
    TOLERATIONS=tolerations,
  ) +
  grafana(config) +
  kiali(config) +
  jaeger(config)
