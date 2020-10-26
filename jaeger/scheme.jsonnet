local container = import '../templates/container.jsonnet';
local job = import '../templates/job.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local pod = import '../templates/pod.jsonnet';

local app = 'jaeger';
local appSchema = 'jaeger-schema';
local image = 'jaegertracing/jaeger-cassandra-schema:1.19.2';

function(config)
  local ns = config.jaeger.namespace;
  local jaeger = config.jaeger;
  local cassandra = jaeger.cassandra;

  [
    job.new() +
    metadata.new(appSchema, ns=ns) +
    job.pod(
      pod.new() +
      metadata.new(appSchema) +
      pod.container(
        container.new(appSchema, image) +
        container.command(['sh', '-c', |||
          /cassandra-schema/docker.sh
          curl --request POST --silent --fail http://localhost:15020/quitquitquit
        |||]) +
        container.envFrom(secret=app) +
        container.env({
          MODE: 'prod',
          CQLSH_HOST: '%s %s' % [cassandra.address, cassandra.port],
          [if cassandra.tls.enabled then 'CQLSH_SSL']: '--ssl',
          [if cassandra.tls.enabled then 'SSL_VERSION']: 'TLSv1_2',
          [if cassandra.tls.enabled then 'SSL_VALIDATE']: std.toString(cassandra.tls.hostnameValidation),
          KEYSPACE: cassandra.keyspace,
          TRACE_TTL: '2592000',
        }) +
        container.resources('100m', '100m', '64Mi', '64Mi') +
        container.volume('tmp', '/tmp') +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.volumeEmptyDir('tmp', '1Mi') +
      pod.securityContext({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.affinity(jaeger.affinity) +
      pod.tolerations(jaeger.tolerations)
    ),
  ]
