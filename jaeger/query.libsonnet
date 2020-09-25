local accesspolicy = import '../templates/accesspolicy.libsonnet';
local certificate = import '../templates/certificate.libsonnet';
local container = import '../templates/container.libsonnet';
local deployment = import '../templates/deployment.libsonnet';
local destinationrule = import '../templates/destinationrule.libsonnet';
local gateway = import '../templates/gateway.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local pod = import '../templates/pod.libsonnet';
local secret = import '../templates/secret.libsonnet';
local service = import '../templates/service.libsonnet';
local virtualservice = import '../templates/virtualservice.libsonnet';

local app = 'jaeger';
local query_app = 'jaeger-query';
local query_image = 'jaegertracing/jaeger-query:1.19.2';

function(config)
  local ns = config.jaeger.namespace;
  local jaeger = config.jaeger;
  local keycloak = config.keycloak;

  (if jaeger.tls.acme then [certificate.new(jaeger.external_address)] else []) +
  [
    gateway.new(jaeger.external_address, tls=jaeger.tls.enabled) +
    metadata.new(app, ns=ns),

    virtualservice.new() +
    metadata.new(app, ns=ns) +
    virtualservice.host(jaeger.external_address) +
    virtualservice.gateway(app) +
    virtualservice.route(query_app, port=16686),

    accesspolicy.new(app) +
    metadata.new(app, ns=ns) +
    accesspolicy.credentials(app),

    secret.new() +
    metadata.new(app, ns=ns) +
    secret.data({
      clientID: jaeger.oidc.client_id,
      clientSecret: jaeger.oidc.client_secret,
    }),

    destinationrule.new(query_app) +
    metadata.new(query_app, ns=ns) +
    destinationrule.circuit_breaker(),

    service.new(query_app) +
    metadata.new(query_app, ns=ns) +
    service.port(16686) +
    service.port(16687, name='http-telemetry'),

    deployment.new(replicas=jaeger.replicas) +
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
        container.env_from(secret=app) +
        container.env({
          SPAN_STORAGE_TYPE: 'cassandra',
          JAEGER_DISABLED: 'true',
        }) +
        container.port('http', 16686) +
        container.port('http-telemetry', 16687) +
        container.volume('config', '/etc/jaeger') +
        container.resources('200m', '200m', '128Mi', '128Mi') +
        container.http_probe('readiness', '/', port='http') +
        container.http_probe('liveness', '/', port='http-telemetry') +
        container.security_context({ readOnlyRootFilesystem: true })
      ) +
      pod.volume_configmap('config', configmap=app) +
      pod.security_context({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.affinity(jaeger.affinity) +
      pod.tolerations(jaeger.tolerations)
    ),
  ]
