local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
local daemonset = import '../templates/daemonset.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local pod = import '../templates/pod.libsonnet';
local role = import '../templates/role.libsonnet';
local rolebinding = import '../templates/rolebinding.libsonnet';
local service = import '../templates/service.libsonnet';
local serviceaccount = import '../templates/serviceaccount.libsonnet';

local app = 'promtail';
local image = 'grafana/promtail:1.4.1';

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
    service.port(80, name='http-telemetry'),

    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'promtail.yaml': std.manifestYamlDoc((import 'promtail.yaml.libsonnet')(config)),
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
        container.volume('config', '/etc/promtail', read_only=true) +
        container.volume('lib', '/var/lib/promtail') +
        container.volume('pod-logs', '/var/log/pods', read_only=true) +
        (if promtail.log_type == 'docker'
         then container.volume('docker-logs', '/var/lib/docker/containers', read_only=true)
         else {}) +
        container.resources('100m', '100m', '128Mi', '128Mi') +
        container.http_probe('readiness', '/ready', port='http-telemetry') +
        container.http_probe('liveness', '/ready', port='http-telemetry') +
        container.security_context({ readOnlyRootFilesystem: true })
      ) +
      pod.service_account(app) +
      pod.volume_configmap('config', configmap=app) +
      pod.volume_hostpath('lib', path='/var/lib/promtail', type='DirectoryOrCreate') +
      pod.volume_hostpath('pod-logs', path='/var/log/pods') +
      (if promtail.log_type == 'docker'
       then pod.volume_hostpath('docker-logs', path='/var/lib/docker/containers')
       else {}) +
      pod.security_context({ runAsUser: 0, runAsGroup: 1000 })
    ),
  ]
