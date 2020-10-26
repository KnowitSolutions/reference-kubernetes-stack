local container = import '../templates/container.jsonnet';
local deployment = import '../templates/deployment.jsonnet';
local destinationrule = import '../templates/destinationrule.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local peerauthentication = import '../templates/peerauthentication.jsonnet';
local pod = import '../templates/pod.jsonnet';
local service = import '../templates/service.jsonnet';

local app = 'jaeger';
local collectorApp = 'jaeger-collector';
local image = 'jaegertracing/jaeger-collector:1.19.2';

function(config)
  local ns = config.jaeger.namespace;
  local jaeger = config.jaeger;

  [
    destinationrule.new(collectorApp) +
    metadata.new(collectorApp, ns=ns) +
    destinationrule.circuitBreaker(),

    service.new(collectorApp) +
    metadata.new(collectorApp, ns=ns) +
    service.port(9411) +
    service.port(14269, name='http-telemetry'),

    peerauthentication.new({ app: collectorApp }) +
    metadata.new(collectorApp, ns=ns) +
    peerauthentication.mtls(false, 9411),

    deployment.new(replicas=jaeger.replicas) +
    metadata.new(collectorApp, ns=ns) +
    deployment.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '14269',
        'json-logs': 'true',
        'json-log-key': 'msg',
      }) +
      pod.container(
        container.new(collectorApp, image) +
        container.args(['--config-file', '/etc/jaeger/collector.yaml']) +
        container.envFrom(secret=app) +
        container.env({ SPAN_STORAGE_TYPE: 'cassandra' }) +
        container.port('http', 9411) +
        container.port('http-telemetry', 14269) +
        container.volume('config', '/etc/jaeger') +
        container.resources('50m', '50m', '32Mi', '32Mi') +
        container.httpProbe('readiness', '/', port='http-telemetry') +
        container.httpProbe('liveness', '/', port='http-telemetry') +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.volumeConfigMap('config', configmap=app) +
      pod.securityContext({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.affinity(jaeger.affinity) +
      pod.tolerations(jaeger.tolerations)
    ),
  ]
