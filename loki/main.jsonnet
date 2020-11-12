local configmap = import '../templates/configmap.jsonnet';
local container = import '../templates/container.jsonnet';
local deployment = import '../templates/deployment.jsonnet';
local destinationrule = import '../templates/destinationrule.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local pod = import '../templates/pod.jsonnet';
local secret = import '../templates/secret.jsonnet';
local service = import '../templates/service.jsonnet';

local app = 'loki';
local image = 'grafana/loki:2.0.0';

function(global, loki, cassandra)
  [
    destinationrule.new(app) +
    metadata.new(app, global.namespace) +
    destinationrule.circuitBreaker(),

    service.new(app) +
    metadata.new(app, global.namespace) +
    service.port(8080),

    destinationrule.new('%s-gossip' % app) +
    metadata.new('%s-gossip' % app, global.namespace) +
    destinationrule.circuitBreaker(),

    service.new(app, headless=true, onlyReady=false) +
    metadata.new(app + '-gossip', global.namespace) +
    service.port(7946, name='tcp-gossip') +
    service.port(9095, name='tcp-grpc'),

    configmap.new() +
    metadata.new(app, global.namespace) +
    configmap.data({
      'loki.yaml': std.manifestYamlDoc((import 'loki.yaml.jsonnet')(loki, cassandra)),
    }),

    secret.new() +
    metadata.new(app, global.namespace) +
    secret.data({
      [if cassandra.username != null then 'CASSANDRA_USERNAME']: cassandra.username,
      [if cassandra.password != null then 'CASSANDRA_PASSWORD']: cassandra.password,
    }),

    deployment.new(replicas=loki.replicas) +
    metadata.new(app, global.namespace) +
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
        container.env({
          [if cassandra.username != null then 'CASSANDRA_USERNAME']:
            { secretKeyRef: { name: app, key: 'CASSANDRA_USERNAME' } },
          [if cassandra.password != null then 'CASSANDRA_PASSWORD']:
            { secretKeyRef: { name: app, key: 'CASSANDRA_PASSWORD' } },
        }) +
        container.port('http', 8080) +
        container.port('tcp-gossip', 7946) +
        container.port('tcp-grpc', 9095) +
        container.volume('config', '/etc/loki') +
        container.resources('500m', '500m', '512Mi', '512Mi') +
        container.httpProbe('readiness', '/ready') +
        container.httpProbe('liveness', '/ready', delay=120) +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.volumeConfigMap('config', configmap=app) +
      pod.securityContext({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.affinity(global.affinity) +
      pod.tolerations(global.tolerations)
    ),
  ]
