local cassandra = import 'cassandra/main.jsonnet';
local istioOidc = import 'github.com/KnowitSolutions/istio-oidc/deployment/main.jsonnet';
local grafana = import 'grafana/main.jsonnet';
local jaeger = import 'jaeger/main.jsonnet';
local keycloak = import 'keycloak/main.jsonnet';
local kiali = import 'kiali/main.jsonnet';
local kubeStateMetrics = import 'kube-state-metrics/main.jsonnet';
local loki = import 'loki/main.jsonnet';
local mssql = import 'mssql/main.jsonnet';
local nodeExporter = import 'node-exporter/main.jsonnet';
local postgres = import 'postgres/main.jsonnet';
local prometheus = import 'prometheus/main.jsonnet';
local promtail = import 'promtail/main.jsonnet';
local metadata = import 'templates/metadata.jsonnet';
local namespace = import 'templates/namespace.jsonnet';
local peerauthentication = import 'templates/peerauthentication.jsonnet';
local pod = import 'templates/pod.jsonnet';

function(
  NAMESPACE='base',
  AFFINITY=[],
  TOLERATIONS=[],

  CERTIFICATE_ISSUER=null,
  INGRESS_TLS=false,

  CASSANDRA_REPLICAS=3,
  CASSANDRA_VIP='10.0.10.1',
  CASSANDRA_ADDRESS=null,
  CASSANDRA_PORT=9042,
  CASSANDRA_USERNAME=null,
  CASSANDRA_PASSWORD=null,
  CASSANDRA_TLS=false,
  CASSANDRA_TLS_HOSTNAME_VALIDATION=true,
  CASSANDRA_TIMEOUT='1s',

  POSTGRES_VIP='10.0.10.2',
  POSTGRES_ADDRESS=null,
  POSTGRES_PORT=5432,
  POSTGRES_USERNAME=null,
  POSTGRES_PASSWORD=null,
  POSTGRES_TLS=false,
  POSTGRES_TLS_HOSTNAME_VALIDATION=true,

  MSSQL_VIP='10.0.10.3',
  MSSQL_ADDRESS=null,
  MSSQL_PORT=1433,
  MSSQL_USERNAME=null,
  MSSQL_PASSWORD=null,
  MSSQL_TLS=false,
  MSSQL_TLS_HOSTNAME_VALIDATION=true,

  PROMETHEUS_REPLICAS=2,
  LOKI_REPLICAS=2,
  LOKI_KEYSPACE='loki',
  PROMTAIL_LOG_TYPE='cri',  // Valid choices: cri, docker, raw

  KEYCLOAK_REPLICAS=2,
  KEYCLOAK_ADDRESS,
  KEYCLOAK_DATABASE='keycloak',
  KEYCLOAK_USERNAME='admin',
  KEYCLOAK_PASSWORD='admin',

  ISTIO_OIDC_REPLICAS=2,

  GRAFANA_REPLICAS=2,
  GRAFANA_ADDRESS,
  GRAFANA_DATABASE='grafana',
  GRAFANA_CLIENT_SECRET='Regenerate me',
  GRAFANA_DASHBOARDS=true,

  KIALI_REPLICAS=2,
  KIALI_ADDRESS,
  KIALI_CLIENT_SECRET='Regenerate me',

  JAEGER_REPLICAS=2,
  JAEGER_ADDRESS,
  JAEGER_KEYSPACE='jaeger',
  JAEGER_CLIENT_SECRET='Regenerate me',
)
  local globalCfg = {
    namespace: NAMESPACE,
    affinity: AFFINITY,
    tolerations: TOLERATIONS,
    certificateIssuer: CERTIFICATE_ISSUER,
    tls: INGRESS_TLS,
  };

  local cassandraCfg = {
    _:: if CASSANDRA_ADDRESS == null
    then assert
      CASSANDRA_VIP == '10.0.10.1' &&
      CASSANDRA_ADDRESS == null &&
      CASSANDRA_PORT == 9042 &&
      CASSANDRA_USERNAME == null &&
      CASSANDRA_PASSWORD == null &&
      CASSANDRA_TLS == false :
      'Cannot override Cassandra connection details when using bundled instance'; {}
    else assert
      CASSANDRA_REPLICAS == 3 :
      'Cannot override Cassandra settings when using external instance'; {},
    bundled: CASSANDRA_ADDRESS == null,
    replicas: CASSANDRA_REPLICAS,
    internalAddress: CASSANDRA_VIP,
    address: if CASSANDRA_ADDRESS == null then 'cassandra.%s' % NAMESPACE else CASSANDRA_VIP,
    externalAddress: CASSANDRA_ADDRESS,
    port: CASSANDRA_PORT,
    username: CASSANDRA_USERNAME,
    password: CASSANDRA_PASSWORD,
    tls: {
      enabled: CASSANDRA_TLS,
      hostnameValidation: CASSANDRA_TLS_HOSTNAME_VALIDATION,
    },
    timeout: CASSANDRA_TIMEOUT,
  };

  local sqlCfg = if POSTGRES_ADDRESS != null then {
    _:: if POSTGRES_ADDRESS == null
    then assert
      POSTGRES_USERNAME != null &&
      POSTGRES_PASSWORD != null :
      'Missing Postgres credentials'; {},
    vendor: 'postgres',
    address: POSTGRES_VIP,
    port: POSTGRES_PORT,
    username: POSTGRES_USERNAME,
    password: POSTGRES_PASSWORD,
    tls: {
      enabled: POSTGRES_TLS,
      hostnameValidation: POSTGRES_TLS_HOSTNAME_VALIDATION,
    },
  }
  else if MSSQL_ADDRESS != null then {
    _:: if MSSQL_ADDRESS != null
    then assert
      MSSQL_USERNAME != null &&
      MSSQL_PASSWORD != null :
      'Missing SQL Server credentials'; {},
    vendor: 'mssql',
    address: MSSQL_VIP,
    port: MSSQL_PORT,
    username: MSSQL_USERNAME,
    password: MSSQL_PASSWORD,
    tls: {
      enabled: MSSQL_TLS,
      hostnameValidation: MSSQL_TLS_HOSTNAME_VALIDATION,
    },
  }
  else error 'Missing SQL configuration';

  local postgresCfg = {
    internalAddress: POSTGRES_VIP,
    externalAddress: POSTGRES_ADDRESS,
    port: POSTGRES_PORT,
  };

  local mssqlCfg = {
    internalAddress: MSSQL_VIP,
    externalAddress: MSSQL_ADDRESS,
    port: MSSQL_PORT,
  };

  local prometheusCfg = {
    replicas: PROMETHEUS_REPLICAS,
  };

  local lokiCfg = {
    replicas: LOKI_REPLICAS,
    keyspace: LOKI_KEYSPACE,
  };

  local promtailCfg = {
    logType: PROMTAIL_LOG_TYPE,
  };

  local keycloakCfg = {
    replicas: KEYCLOAK_REPLICAS,
    database: KEYCLOAK_DATABASE,
    externalAddress: KEYCLOAK_ADDRESS,
    internalAddress: 'keycloak.%s' % NAMESPACE,
    admin: {
      username: KEYCLOAK_USERNAME,
      password: KEYCLOAK_PASSWORD,
    },
  };

  local grafanaCfg = {
    assert GRAFANA_REPLICAS == 1 || sqlCfg.vendor == 'postgres' :
           'Grafana high availability in unavailable without Postgres',
    replicas: GRAFANA_REPLICAS,
    externalAddress: GRAFANA_ADDRESS,
    database: GRAFANA_DATABASE,
    oidc: {
      clientId: 'grafana',
      clientSecret: GRAFANA_CLIENT_SECRET,
    },
    dashboards: GRAFANA_DASHBOARDS,
  };

  local kialiCfg = {
    replicas: KIALI_REPLICAS,
    externalAddress: KIALI_ADDRESS,
    oidc: {
      clientId: 'kiali',
      clientSecret: KIALI_CLIENT_SECRET,
    },
  };

  local jaegerCfg = {
    replicas: JAEGER_REPLICAS,
    keyspace: JAEGER_KEYSPACE,
    externalAddress: JAEGER_ADDRESS,
    oidc: {
      clientId: 'jaeger',
      clientSecret: JAEGER_CLIENT_SECRET,
    },
  };

  [
    peerauthentication.new() +
    metadata.new('default', ns='istio-system') +
    peerauthentication.mtls(true),

    namespace.new() +
    metadata.new(NAMESPACE),
  ] +
  cassandra(globalCfg, cassandraCfg) +
  postgres(globalCfg, postgresCfg) +
  mssql(globalCfg, mssqlCfg) +
  prometheus(globalCfg, prometheusCfg) +
  loki(globalCfg, lokiCfg, cassandraCfg) +
  promtail(globalCfg, promtailCfg) +
  nodeExporter(globalCfg) +
  kubeStateMetrics(globalCfg) +
  istioOidc(
    NAMESPACE=NAMESPACE,
    VERSION='latest',
    REPLICAS=ISTIO_OIDC_REPLICAS,
    AFFINITY=pod.affinity(AFFINITY).spec.affinity,
    TOLERATIONS=pod.tolerations(TOLERATIONS).spec.tolerations,
  ) +
  keycloak(globalCfg, keycloakCfg, sqlCfg, grafanaCfg, kialiCfg, jaegerCfg) +
  grafana(globalCfg, grafanaCfg, sqlCfg, keycloakCfg) +
  kiali(globalCfg, kialiCfg, grafanaCfg, jaegerCfg) +
  jaeger(globalCfg, jaegerCfg, cassandraCfg)
