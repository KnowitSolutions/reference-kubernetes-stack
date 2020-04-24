local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
local deployment = import '../templates/deployment.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local pod = import '../templates/pod.libsonnet';
local secret = import '../templates/secret.libsonnet';
local service = import '../templates/service.libsonnet';

local app = 'loki';
local image = 'grafana/loki:v1.3.0';

function(config)
  local ns = config.loki.namespace;
  local loki = config.loki;
  local cassandra = loki.cassandra;

  [
    service.new(app) +
    metadata.new(app, ns=ns) +
    service.port(80),

    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'loki.yaml': std.manifestYamlDoc((import 'loki.yaml.libsonnet')(config)),
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
        container.env_from(secret=app) +
        container.port('http', 8080) +
        container.volume('config', '/etc/loki') +
        container.resources('100m', '100m', '128Mi', '128Mi') +
        container.http_probe('readiness', '/ready') +
        container.http_probe('liveness', '/ready', delay=120)
      ) +
      pod.volume_configmap('config', configmap=app) +
      pod.security_context({ runAsUser: 1000, runAsGroup: 1000 })
    ),
  ]
