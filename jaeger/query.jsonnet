local accesspolicy = import '../templates/accesspolicy.jsonnet';
local certificate = import '../templates/certificate.jsonnet';
local container = import '../templates/container.jsonnet';
local deployment = import '../templates/deployment.jsonnet';
local destinationrule = import '../templates/destinationrule.jsonnet';
local gateway = import '../templates/gateway.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local pod = import '../templates/pod.jsonnet';
local secret = import '../templates/secret.jsonnet';
local service = import '../templates/service.jsonnet';
local virtualservice = import '../templates/virtualservice.jsonnet';

local app = 'jaeger';
local queryApp = 'jaeger-query';
local schemaApp = 'jaeger-schema';
local queryImage = 'jaegertracing/jaeger-query:1.19.2';
local schemaImage = 'jaegertracing/jaeger-cassandra-schema:1.19.2';

function(global, jaeger, cassandra)
  (if global.tls then [certificate.new(jaeger.externalAddress)] else []) +
  [
    gateway.new(jaeger.externalAddress, tls=global.tls) +
    metadata.new(app, global.namespace),

    virtualservice.new() +
    metadata.new(app, global.namespace) +
    virtualservice.host(jaeger.externalAddress) +
    virtualservice.gateway(app) +
    virtualservice.route(queryApp, port=16686),

    accesspolicy.new(app, 'keycloak') +
    metadata.new(app, global.namespace) +
    accesspolicy.credentials(app),

    destinationrule.new(queryApp) +
    metadata.new(queryApp, global.namespace) +
    destinationrule.circuitBreaker(),

    service.new(queryApp) +
    metadata.new(queryApp, global.namespace) +
    service.port(16686) +
    service.port(16687, name='http-telemetry'),

    deployment.new(replicas=jaeger.replicas) +
    metadata.new(queryApp, global.namespace) +
    deployment.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '16687',
        'json-logs': 'true',
        'json-log-key': 'msg',
      }) +
      pod.container(
        container.new(schemaApp, schemaImage) +
        container.command(['sh', '-c', '/cassandra-schema/docker.sh && sleep infinity']) +
        container.env({
          MODE: 'prod',
          CQLSH_HOST: '%s %s' % [cassandra.address, cassandra.port],
          [if cassandra.username != null then 'CASSANDRA_USERNAME']:
            { secretKeyRef: { name: app, key: 'CASSANDRA_USERNAME' } },
          [if cassandra.password != null then 'CASSANDRA_PASSWORD']:
            { secretKeyRef: { name: app, key: 'CASSANDRA_PASSWORD' } },
          [if cassandra.tls.enabled then 'CQLSH_SSL']: '--ssl',
          [if cassandra.tls.enabled then 'SSL_VERSION']: 'TLSv1_2',
          [if cassandra.tls.enabled then 'SSL_VALIDATE']: std.toString(cassandra.tls.hostnameValidation),
          KEYSPACE: jaeger.keyspace,
          TRACE_TTL: '2592000',
        }) +
        container.resources('0', '100m', '8Mi', '64Mi') +
        container.volume('tmp', '/tmp') +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.container(
        container.new(queryApp, queryImage) +
        container.args(['--config-file', '/etc/jaeger/query.yaml']) +
        container.env({
          [if cassandra.username != null then 'CASSANDRA_USERNAME']:
            { secretKeyRef: { name: app, key: 'CASSANDRA_USERNAME' } },
          [if cassandra.password != null then 'CASSANDRA_PASSWORD']:
            { secretKeyRef: { name: app, key: 'CASSANDRA_PASSWORD' } },
          SPAN_STORAGE_TYPE: 'cassandra',
          JAEGER_DISABLED: 'true',
        }) +
        container.port('http', 16686) +
        container.port('http-telemetry', 16687) +
        container.volume('config', '/etc/jaeger') +
        container.resources('50m', '200m', '128Mi', '128Mi') +
        container.httpProbe('readiness', '/', port='http') +
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
