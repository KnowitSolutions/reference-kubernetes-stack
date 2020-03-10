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
local image = 'grafana/promtail:v1.3.0';

function(config)
  local ns = config.promtail.namespace;

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
      'promtail.yaml': importstr 'promtail.yaml',
    }),

    daemonset.new() +
    metadata.new(app, ns=ns) +
    daemonset.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': 'http',
      }) +
      pod.container(
        container.new(app, image) +
        container.args(['-config.file', '/etc/promtail/promtail.yaml']) +
        container.env({ HOSTNAME: { fieldRef: { fieldPath: 'spec.nodeName' } } }) +
        container.port('http-telemetry', 80) +
        container.volume('config', '/etc/promtail') +
        container.volume('logs', '/var/log') +
        container.resources('100m', '200m', '128Mi', '256Mi') +
        container.http_probe('readiness', '/ready')
      ) +
      pod.service_account(app) +
      pod.volume_configmap('config', configmap=app) +
      pod.volume_hostpath('logs', path='/var/log')
      // TODO: pod.security_context({ runAsUser: 472 })
    ),
  ]
