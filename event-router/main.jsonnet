local configmap = import '../templates/configmap.jsonnet';
local container = import '../templates/container.jsonnet';
local deployment = import '../templates/deployment.jsonnet';
local destinationrule = import '../templates/destinationrule.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local pod = import '../templates/pod.jsonnet';
local role = import '../templates/role.jsonnet';
local rolebinding = import '../templates/rolebinding.jsonnet';
local service = import '../templates/service.jsonnet';
local serviceaccount = import '../templates/serviceaccount.jsonnet';

local app = 'event-router';
local version = 'v0.3';
local image = 'gcr.io/heptio-images/eventrouter:' + version;

function(global)
  [
    serviceaccount.new() +
    metadata.new(app, global.namespace),

    role.new(cluster=true) +
    metadata.new(app + '-' + global.namespace) +
    role.rule({
      apiGroups: [''],
      verbs: ['get', 'list', 'watch'],
      resources: ['events'],
    }),

    rolebinding.new(cluster=true) +
    metadata.new(app + '-' + global.namespace) +
    rolebinding.role(app + '-' + global.namespace, cluster=true) +
    rolebinding.subject('ServiceAccount', app, global.namespace),

    destinationrule.new(app) +
    metadata.new(app, global.namespace) +
    destinationrule.circuitBreaker(),

    service.new(app) +
    metadata.new(app, global.namespace) +
    service.port(8080, name='http-telemetry'),

    configmap.new() +
    metadata.new(app, global.namespace) +
    configmap.data({
      'config.json': std.manifestJson({ sink: 'stdout' }),
    }),

    deployment.new(version=version) +
    metadata.new(app, global.namespace) +
    deployment.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '8080',
      }) +
      pod.container(
        container.new(app, image) +
        container.port('http-telemetry', 8080) +
        container.volume('config', '/etc/eventrouter') +
        container.volume('tmp', '/tmp') +
        container.resources('10m', '100m', '32Mi', '32Mi') +
        container.httpProbe('readiness', '/metrics', port='http-telemetry') +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.serviceAccount(app) +
      pod.volumeConfigMap('config', configmap=app) +
      pod.volumeEmptyDir('tmp', '1Mi') +
      pod.securityContext({ runAsUser: 65534, runAsGroup: 65534 }) +
      pod.affinity(global.affinity) +
      pod.tolerations(global.tolerations)
    ),
  ]
