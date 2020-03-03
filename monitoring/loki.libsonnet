local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
local deployment = import '../templates/deployment.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local pod = import '../templates/pod.libsonnet';
local service = import '../templates/service.libsonnet';

local app = 'loki';
local image = 'grafana/loki:v1.3.0';

function(config)
  local ns = config.loki.namespace;

  [
    service.new(app) +
    metadata.new(app, ns=ns) +
    service.port(80),

    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'loki.yaml': importstr 'loki.yaml',
    }),

    deployment.new() +
    metadata.new(app, ns=ns) +
    deployment.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': 'http',
      }) +
      pod.container(
        container.new(app, image) +
        container.args(['-config.file', '/etc/loki/loki.yaml']) +
        container.port('http', 80) +
        container.volume('config', '/etc/loki') +
        container.resources('100m', '200m', '128Mi', '256Mi') +
        container.http_probe('readiness', '/ready')
      ) +
      pod.volume_configmap('config', configmap=app)
      // TODO: pod.security_context({ runAsUser: 472 })
    ),
  ]
