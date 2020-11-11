local container = import '../templates/container.jsonnet';
local deployment = import '../templates/deployment.jsonnet';
local destinationrule = import '../templates/destinationrule.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local peerauthentication = import '../templates/peerauthentication.jsonnet';
local pod = import '../templates/pod.jsonnet';
local service = import '../templates/service.jsonnet';

local app = 'jaeger';
local collectorApp = 'jaeger-collector';
local schemaApp = 'jaeger-schema';
local collectorImage = 'jaegertracing/jaeger-collector:1.19.2';
local schemaImage = 'jaegertracing/jaeger-cassandra-schema:1.19.2';

function(global, jaeger, cassandra)
  [
    destinationrule.new(collectorApp) +
    metadata.new(collectorApp, global.namespace) +
    destinationrule.circuitBreaker(),

    service.new(collectorApp) +
    metadata.new(collectorApp, global.namespace) +
    service.port(9411) +
    service.port(14269, name='http-telemetry'),

    peerauthentication.new({ app: collectorApp }) +
    metadata.new(collectorApp, global.namespace) +
    peerauthentication.mtls(false, 9411),

    deployment.new(replicas=jaeger.replicas) +
    metadata.new(collectorApp, global.namespace) +
    deployment.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '14269',
        'json-logs': 'true',
        'json-log-key': 'msg',
      }) +
      pod.container(
        container.new(schemaApp, schemaImage) +
        container.command(['sh', '-c', '/cassandra-schema/docker.sh && sleep infinity']) +
        container.envFrom(secret=app) +
        container.env({
          MODE: 'prod',
          CQLSH_HOST: '%s %s' % [cassandra.address, cassandra.port],
          [if cassandra.tls.enabled then 'CQLSH_SSL']: '--ssl',
          [if cassandra.tls.enabled then 'SSL_VERSION']: 'TLSv1_2',
          [if cassandra.tls.enabled then 'SSL_VALIDATE']: std.toString(cassandra.tls.hostnameValidation),
          KEYSPACE: jaeger.keyspace,
          TRACE_TTL: '2592000',
        }) +
        container.resources('100m', '100m', '64Mi', '64Mi') +
        container.volume('tmp', '/tmp') +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.container(
        container.new(collectorApp, collectorImage) +
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
      pod.volumeEmptyDir('tmp', '1Mi') +
      pod.securityContext({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.affinity(global.affinity) +
      pod.tolerations(global.tolerations)
    ),
  ]
