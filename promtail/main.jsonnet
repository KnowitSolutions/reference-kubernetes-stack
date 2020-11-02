local configmap = import '../templates/configmap.jsonnet';
local container = import '../templates/container.jsonnet';
local daemonset = import '../templates/daemonset.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local pod = import '../templates/pod.jsonnet';
local role = import '../templates/role.jsonnet';
local rolebinding = import '../templates/rolebinding.jsonnet';
local service = import '../templates/service.jsonnet';
local serviceaccount = import '../templates/serviceaccount.jsonnet';

local app = 'promtail';
local image = 'grafana/promtail:1.6.1';

function(config)
  local ns = config.promtail.namespace;
  local promtail = config.promtail;

  [
    serviceaccount.new() +
    metadata.new(app, ns=ns),

    role.new(cluster=true) +
    metadata.new('%s-%s' % [app, ns]) +
    role.rule({
      apiGroups: [''],
      verbs: ['get', 'list', 'watch'],
      resources: ['pods'],
    }),

    rolebinding.new(cluster=true) +
    metadata.new('%s-%s' % [app, ns]) +
    rolebinding.role('%s-%s' % [app, ns], cluster=true) +
    rolebinding.subject('ServiceAccount', app, ns=ns),

    service.new(app) +
    metadata.new(app, ns=ns) +
    service.port(8080, name='http-telemetry'),

    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'promtail.yaml': std.manifestYamlDoc((import 'promtail.yaml.jsonnet')(config)),
    }),

    daemonset.new() +
    metadata.new(app, ns=ns) +
    daemonset.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '8080',
      }) +
      pod.container(
        container.new(app, image) +
        container.args(['-config.file', '/etc/promtail/promtail.yaml']) +
        container.env({ HOSTNAME: { fieldRef: { fieldPath: 'spec.nodeName' } } }) +
        container.port('http-telemetry', 8080) +
        container.volume('config', '/etc/promtail', readOnly=true) +
        container.volume('lib', '/var/lib/promtail') +
        container.volume('pod-logs', '/var/log/pods', readOnly=true) +
        (if promtail.logType == 'docker'
         then container.volume('docker-logs', '/var/lib/docker/containers', readOnly=true)
         else {}) +
        container.resources('100m', '100m', '128Mi', '128Mi') +
        container.httpProbe('readiness', '/ready', port='http-telemetry') +
        container.httpProbe('liveness', '/ready', port='http-telemetry') +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.serviceAccount(app) +
      pod.volumeConfigMap('config', configmap=app) +
      pod.volumeHostPath('lib', path='/var/lib/promtail', type='DirectoryOrCreate') +
      pod.volumeHostPath('pod-logs', path='/var/log/pods') +
      (if promtail.logType == 'docker'
       then pod.volumeHostPath('docker-logs', path='/var/lib/docker/containers')
       else {}) +
      pod.securityContext({ runAsUser: 0, runAsGroup: 1000 }) +
      pod.tolerations(anything=true)
    ),
  ]
