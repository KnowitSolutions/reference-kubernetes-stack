local container = import '../templates/container.jsonnet';
local deployment = import '../templates/deployment.jsonnet';
local destinationrule = import '../templates/destinationrule.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local peerauthentication = import '../templates/peerauthentication.jsonnet';
local pod = import '../templates/pod.jsonnet';
local service = import '../templates/service.jsonnet';

local app = 'jaeger';
local collector_app = 'jaeger-collector';
local image = 'jaegertracing/jaeger-collector:1.19.2';

function(config)
  local ns = config.jaeger.namespace;
  local jaeger = config.jaeger;

  [
    destinationrule.new(collector_app) +
    metadata.new(collector_app, ns=ns) +
    destinationrule.circuit_breaker(),

    service.new(collector_app) +
    metadata.new(collector_app, ns=ns) +
    service.port(9411) +
    service.port(14269, name='http-telemetry'),

    peerauthentication.new({ app: collector_app }) +
    metadata.new(collector_app, ns=ns) +
    peerauthentication.mtls(false, 9411),

    deployment.new(replicas=jaeger.replicas) +
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
        container.new(collector_app, image) +
        container.args(['--config-file', '/etc/jaeger/collector.yaml']) +
        container.env_from(secret=app) +
        container.env({ SPAN_STORAGE_TYPE: 'cassandra' }) +
        container.port('http', 9411) +
        container.port('http-telemetry', 14269) +
        container.volume('config', '/etc/jaeger') +
        container.resources('50m', '50m', '32Mi', '32Mi') +
        container.http_probe('readiness', '/', port='http-telemetry') +
        container.http_probe('liveness', '/', port='http-telemetry') +
        container.security_context({ readOnlyRootFilesystem: true })
      ) +
      pod.volume_configmap('config', configmap=app) +
      pod.security_context({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.affinity(jaeger.affinity) +
      pod.tolerations(jaeger.tolerations)
    ),
  ]
