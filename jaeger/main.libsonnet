local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
local deployment = import '../templates/deployment.libsonnet';
local gateway = import '../templates/gateway.libsonnet';
local job = import '../templates/job.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local peerauthentication = import '../templates/peerauthentication.libsonnet';
local pod = import '../templates/pod.libsonnet';
local service = import '../templates/service.libsonnet';
local virtualservice = import '../templates/virtualservice.libsonnet';

local app = 'jaeger';
local app_schema = 'jaeger-schema';
local schema_image = 'jaegertracing/jaeger-cassandra-schema:1.17.1';
local collector_app = 'jaeger-collector';
local collector_image = 'jaegertracing/jaeger-collector:1.17.1';
local query_app = 'jaeger-query';
local query_image = 'jaegertracing/jaeger-query:1.17.1';
local auth_app = 'oauth2-proxy';
local auth_image = 'quay.io/oauth2-proxy/oauth2-proxy:v5.1.0';

function(config)
  local ns = config.jaeger.namespace;
  local jaeger = config.jaeger;
  local keycloak = config.keycloak;

  [
    job.new() +
    metadata.new(app_schema, ns=ns) +
    job.pod(
      pod.new() +
      metadata.new(app_schema) +
      pod.container(
        container.new(app_schema, schema_image) +
        container.command(['sh', '-c', |||
          /cassandra-schema/docker.sh
          curl --request POST --silent --fail http://localhost:15020/quitquitquit
        |||]) +
        container.env({
          MODE: 'prod',
          CQLSH_HOST: 'cassandra.db',
          KEYSPACE: 'jaeger',
          TRACE_TTL: '2592000',
        }) +
        container.resources('100m', '100m', '64Mi', '64Mi')
      ) +
      pod.security_context({ runAsUser: 1000, runAsGroup: 1000 })
    ),

    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'collector.yaml': std.manifestYamlDoc((import 'collector.yaml.libsonnet')(config)),
      'query.yaml': std.manifestYamlDoc((import 'query.yaml.libsonnet')(config)),
    }),

    service.new(collector_app) +
    metadata.new(collector_app, ns=ns) +
    service.port(9411) +
    service.port(14269, name='http-telemetry'),

    peerauthentication.new({ app: collector_app }) +
    metadata.new(collector_app, ns=ns) +
    peerauthentication.mtls(false, 9411),

    deployment.new(replicas=2) +
    metadata.new(collector_app, ns=ns) +
    deployment.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '14269',
        'json-logs': 'true',
        'json-log-key': 'msg',
      }) +
      pod.container(
        container.new(collector_app, collector_image) +
        container.args(['--config-file', '/etc/jaeger/collector.yaml']) +
        container.env({ SPAN_STORAGE_TYPE: 'cassandra' }) +
        container.port('http', 9411) +
        container.port('http-telemetry', 14269) +
        container.volume('config', '/etc/jaeger') +
        container.resources('50m', '50m', '16Mi', '16Mi') +
        container.http_probe('readiness', '/', port='http-telemetry') +
        container.http_probe('liveness', '/', port='http-telemetry')
      ) +
      pod.volume_configmap('config', configmap=app) +
      pod.security_context({ runAsUser: 1000, runAsGroup: 1000 })
    ),

    gateway.new(jaeger.external_address) +
    metadata.new(app, ns=ns),

    virtualservice.new() +
    metadata.new(app, ns=ns) +
    virtualservice.host(jaeger.external_address) +
    virtualservice.gateway(app) +
    virtualservice.route(query_app, port=4180),

    service.new(query_app) +
    metadata.new(query_app, ns=ns) +
    service.port(4180) +
    service.port(16686, name='http-direct') +
    service.port(16687, name='http-telemetry'),

    deployment.new(replicas=2) +
    metadata.new(query_app, ns=ns) +
    deployment.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '16687',
        'json-logs': 'true',
        'json-log-key': 'msg',
      }) +
      pod.container(
        container.new(query_app, query_image) +
        container.args(['--config-file', '/etc/jaeger/query.yaml']) +
        container.env({ SPAN_STORAGE_TYPE: 'cassandra' }) +
        container.port('http-direct', 16686) +
        container.port('http-telemetry', 16687) +
        container.volume('config', '/etc/jaeger') +
        container.resources('10m', '10m', '32Mi', '32Mi') +
        container.http_probe('readiness', '/', port='http-direct') +
        container.http_probe('liveness', '/', port='http-telemetry')
      ) +
      pod.container(
        container.new(auth_app, auth_image) +
        container.args([
          '--upstream=http://127.0.0.1:16686',
          '--skip-provider-button',
          '--provider=oidc',
          '--skip-oidc-discovery=true',
          '--oidc-issuer-url=http://%s/auth/realms/master' % keycloak.external_address,
          '--login-url=http://%s/auth/realms/master/protocol/openid-connect/auth' % keycloak.external_address,
          '--redeem-url=http://%s:8080/auth/realms/master/protocol/openid-connect/token' % keycloak.internal_address,
          '--oidc-jwks-url=http://%s:8080/auth/realms/master/protocol/openid-connect/certs' % keycloak.internal_address,
          '--client-id=%s' % jaeger.oidc.client_id,
          '--client-secret=%s' % jaeger.oidc.client_secret,
          '--redirect-url=http://%s/oauth2/callback' % jaeger.external_address,
          '--cookie-secret=secret',  // TODO: Change
          '--cookie-secure=false',
          '--email-domain=*',
        ]) +
        container.port('http', 4180) +
        // TODO: resources
        container.http_probe('readiness', '/ping') +
        container.http_probe('liveness', '/ping')
      ) +
      pod.volume_configmap('config', configmap=app) +
      pod.security_context({ runAsUser: 1000, runAsGroup: 1000 })
    ),
  ]
