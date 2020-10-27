local configmap = import '../templates/configmap.jsonnet';
local container = import '../templates/container.jsonnet';
local deployment = import '../templates/deployment.jsonnet';
local destinationrule = import '../templates/destinationrule.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local pod = import '../templates/pod.jsonnet';
local secret = import '../templates/secret.jsonnet';
local service = import '../templates/service.jsonnet';

local app = 'loki';
local image = 'grafana/loki:1.6.1';

function(config)
  local ns = config.loki.namespace;
  local loki = config.loki;
  local cassandra = loki.cassandra;

  [
    destinationrule.new(app) +
    metadata.new(app, ns=ns) +
    destinationrule.circuitBreaker(),

    service.new(app) +
    metadata.new(app, ns=ns) +
    service.port(8080),

    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'loki.yaml': std.manifestYamlDoc((import 'loki.yaml.jsonnet')(config)),
    }),

    secret.new() +
    metadata.new(app, ns=ns) +
    secret.data({
      [if cassandra.username != null then 'CASSANDRA_USERNAME']: cassandra.username,
      [if cassandra.password != null then 'CASSANDRA_PASSWORD']: cassandra.password,
    }),

    deployment.new() +
    metadata.new(app, ns=ns) +
    deployment.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '8080',
      }) +
      pod.container(
        container.new(app, image) +
        container.args([
          '-config.file',
          '/etc/loki/loki.yaml',
          '-cassandra.username',
          '$(CASSANDRA_USERNAME)',
          '-cassandra.password',
          '$(CASSANDRA_PASSWORD)',
        ]) +
        container.envFrom(secret=app) +
        container.port('http', 8080) +
        container.volume('config', '/etc/loki') +
        container.resources('500m', '500m', '512Mi', '512Mi') +
        container.httpProbe('readiness', '/ready') +
        container.httpProbe('liveness', '/ready', delay=120) +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.volumeConfigMap('config', configmap=app) +
      pod.securityContext({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.affinity(loki.affinity) +
      pod.tolerations(loki.tolerations)
    ),
  ]