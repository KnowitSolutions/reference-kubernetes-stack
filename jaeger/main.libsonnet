local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
local deployment = import '../templates/deployment.libsonnet';
local job = import '../templates/job.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local peerauthentication = import '../templates/peerauthentication.libsonnet';
local pod = import '../templates/pod.libsonnet';
local service = import '../templates/service.libsonnet';

local app = 'jaeger';
local app_schema = 'jaeger-schema';
local schema_image = 'jaegertracing/jaeger-cassandra-schema:1.17.1';
local collector_app = 'jaeger-collector';
local collector_image = 'jaegertracing/jaeger-collector:1.17.1';
local query_app = 'jaeger-query';
local query_image = 'jaegertracing/jaeger-query:1.17.1';

function(config)
  local ns = config.jaeger.namespace;

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
        })
      ) +
      pod.security_context({ runAsUser: 1000 })
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
        container.http_probe('readiness', '/', port='http-telemetry') +
        container.http_probe('liveness', '/', port='http-telemetry')
      ) +
      pod.volume_configmap('config', configmap=app) +
      pod.security_context({ runAsUser: 1000 })
    ),

    service.new(query_app) +
    metadata.new(query_app, ns=ns) +
    service.port(16686) +
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
        container.port('http', 16686) +
        container.port('http-telemetry', 16687) +
        container.volume('config', '/etc/jaeger') +
        container.http_probe('readiness', '/') +
        container.http_probe('liveness', '/', port='http-telemetry')
      ) +
      pod.volume_configmap('config', configmap=app) +
      pod.security_context({ runAsUser: 1000 })
    ),
  ]
