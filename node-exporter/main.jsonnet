local container = import '../templates/container.jsonnet';
local daemonset = import '../templates/daemonset.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local pod = import '../templates/pod.jsonnet';
local service = import '../templates/service.jsonnet';

local app = 'node-exporter';
local version = 'v1.0.1';
local image = 'prom/node-exporter:' + version;

function(global)
  [
    service.new(app) +
    metadata.new(app, global.namespace) +
    service.port(9100, name='http'),

    daemonset.new(version=version) +
    metadata.new(app, global.namespace) +
    daemonset.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '9100',
      }) +
      pod.container(
        container.new(app, image) +
        container.args([
          '--path.rootfs=/host',
          '--path.procfs=/host/proc',
          '--path.sysfs=/host/sys',
          '--collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/pods/.+)($|/)',
        ]) +
        container.port('http', 9100) +
        container.volume('root', '/host', readOnly=true, propagation='HostToContainer') +
        container.resources('100m', '300m', '200Mi', '200Mi') +
        container.httpProbe('readiness', '/', port='http') +
        container.httpProbe('liveness', '/', port='http') +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.volumeHostPath('root', path='/') +
      pod.host(pid=true, network=true) +
      pod.securityContext({ runAsUser: 65534, runAsGroup: 65534 }) +
      pod.tolerations(anything=true)
    ),
  ]
