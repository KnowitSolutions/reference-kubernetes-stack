local container = import '../templates/container.libsonnet';
local job = import '../templates/job.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local pod = import '../templates/pod.libsonnet';

local app = 'jaeger';
local app_schema = 'jaeger-schema';
local image = 'jaegertracing/jaeger-cassandra-schema:1.19.2';

function(config)
  local ns = config.jaeger.namespace;
  local jaeger = config.jaeger;
  local cassandra = jaeger.cassandra;

  [
    job.new() +
    metadata.new(app_schema, ns=ns) +
    job.pod(
      pod.new() +
      metadata.new(app_schema) +
      pod.container(
        container.new(app_schema, image) +
        container.command(['sh', '-c', |||
          /cassandra-schema/docker.sh
          curl --request POST --silent --fail http://localhost:15020/quitquitquit
        |||]) +
        container.env_from(secret=app) +
        container.env({
          MODE: 'prod',
          CQLSH_HOST: '%s %s' % [cassandra.address, cassandra.port],
          [if cassandra.tls.enabled then 'CQLSH_SSL']: '--ssl',
          [if cassandra.tls.enabled then 'SSL_VERSION']: 'TLSv1_2',
          [if cassandra.tls.enabled then 'SSL_VALIDATE']: std.toString(cassandra.tls.hostname_validation),
          KEYSPACE: cassandra.keyspace,
          TRACE_TTL: '2592000',
        }) +
        container.resources('100m', '100m', '64Mi', '64Mi') +
        container.volume('tmp', '/tmp') +
        container.security_context({ readOnlyRootFilesystem: true })
      ) +
      pod.volume_emptydir('tmp', '1Mi') +
      pod.security_context({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.affinity(jaeger.affinity) +
      pod.tolerations(jaeger.tolerations)
    ),
  ]
