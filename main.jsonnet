local cassandra = import 'cassandra/main.jsonnet';
local grafana = import 'grafana/main.jsonnet';
local istioOidc = import 'istio-oidc/deployment/main.jsonnet';
local jaeger = import 'jaeger/main.jsonnet';
local keycloak = import 'keycloak/main.jsonnet';
local kiali = import 'kiali/main.jsonnet';
local kubeStateMetrics = import 'kube-state-metrics/main.jsonnet';
local loki = import 'loki/main.jsonnet';
local mssql = import 'mssql/main.jsonnet';
local postgres = import 'postgres/main.jsonnet';
local prometheus = import 'prometheus/main.jsonnet';
local promtail = import 'promtail/main.jsonnet';
local issuer = import 'templates/issuer.jsonnet';
local metadata = import 'templates/metadata.jsonnet';
local namespace = import 'templates/namespace.jsonnet';
local peerauthentication = import 'templates/peerauthentication.jsonnet';
local pod = import 'templates/pod.jsonnet';

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

  prometheus_replicas=2,
  loki_replicas=2,
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
  local affinity = if node_selector != null then pod.newAffinity(node_selector) else {};
  local tolerations = if node_tolerations != null then pod.newTolerations(node_tolerations) else [];

  local cassandraConnection = {
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
      hostnameValidation: cassandra_tls_hostname_validation,
    },
    timeout: cassandra_timeout,
  };

  local postgresConnection = {
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
      hostnameValidation: postgres_tls_hostname_validation,
    },
  };

  local mssqlConnection = {
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
      hostnameValidation: mssql_tls_hostname_validation,
    },
  };

  local tlsConfig = {
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
        internalAddress: cassandra_vip,
        externalAddress: cassandra_address,
        port: cassandra_port,
      },
      affinity: affinity,
      tolerations: tolerations,
    },
    postgres: {
      namespace: namespace,
      vip: {
        enabled: postgres_address != null,
        internalAddress: postgres_vip,
        externalAddress: postgres_address,
        port: postgres_port,
      },
    },
    mssql: {
      namespace: namespace,
      vip: {
        enabled: mssql_address != null,
        internalAddress: mssql_vip,
        externalAddress: mssql_address,
        port: mssql_port,
      },
    },
    prometheus: {
      namespace: namespace,
      replicas: prometheus_replicas,
      affinity: affinity,
      tolerations: tolerations,
    },
    loki: {
      namespace: namespace,
      replicas: loki_replicas,
      cassandra: cassandraConnection { keyspace: loki_keyspace },
      affinity: affinity,
      tolerations: tolerations,
    },
    promtail: {
      namespace: namespace,
      logType: promtail_log_type,
      affinity: affinity,
      tolerations: tolerations,
    },
    kubeStateMetrics: {
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
      postgres: postgresConnection { database: keycloak_database },
      mssql: mssqlConnection { database: keycloak_database },
      externalProtocol: if self.tls.enabled then 'https' else 'http',
      externalAddress: keycloak_address,
      internalAddress: 'keycloak.%s' % namespace,
      tls: tlsConfig,
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
      externalProtocol: if self.tls.enabled then 'https' else 'http',
      externalAddress: grafana_address,
      tls: tlsConfig,
      postgres: postgresConnection { database: grafana_database },
      oidc: {
        clientId: 'grafana',
        clientSecret: grafana_client_secret,
      },
      affinity: affinity,
      tolerations: tolerations,
    },
    kiali: {
      namespace: namespace,
      replicas: kiali_replicas,
      externalProtocol: if self.tls.enabled then 'https' else 'http',
      externalAddress: kiali_address,
      tls: tlsConfig,
      oidc: {
        clientId: 'kiali',
        clientSecret: kiali_client_secret,
      },
      affinity: affinity,
      tolerations: tolerations,
    },
    jaeger: {
      namespace: namespace,
      replicas: jaeger_replicas,
      cassandra: cassandraConnection { keyspace: jaeger_keyspace },
      externalProtocol: if self.tls.enabled then 'https' else 'http',
      externalAddress: jaeger_address,
      tls: tlsConfig,
      oidc: {
        clientId: 'jaeger',
        clientSecret: jaeger_client_secret,
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
     issuer.httpSolver(),
   ] else []) +

  cassandra(config) +
  postgres(config) +
  mssql(config) +
  prometheus(config) +
  loki(config) +
  promtail(config) +
  kubeStateMetrics(config) +
  istioOidc(
    NAMESPACE=namespace,
    VERSION='master',
    REPLICAS=istio_oidc_replicas,
    AFFINITY=affinity,
    TOLERATIONS=tolerations,
  ) +
  keycloak(config) +
  grafana(config) +
  kiali(config) +
  jaeger(config)
