local container = import '../templates/container.jsonnet';
local daemonset = import '../templates/daemonset.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local pod = import '../templates/pod.jsonnet';
local service = import '../templates/service.jsonnet';

local app = 'node-exporter';
local image = 'prom/node-exporter:v1.0.1';

function(config)
  local ns = config.nodeExporter.namespace;

  [
    service.new(app) +
    metadata.new(app, ns=ns) +
    service.port(9100, name='http'),

    daemonset.new() +
    metadata.new(app, ns=ns) +
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
        container.resources('100m', '100m', '200Mi', '200Mi') +
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
