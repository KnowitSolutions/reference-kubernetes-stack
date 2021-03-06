local configmap = import '../templates/configmap.jsonnet';
local container = import '../templates/container.jsonnet';
local destinationrule = import '../templates/destinationrule.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local pod = import '../templates/pod.jsonnet';
local service = import '../templates/service.jsonnet';
local serviceentry = import '../templates/serviceentry.jsonnet';
local statefulset = import '../templates/statefulset.jsonnet';

local app = 'cassandra';
local version = '3.11.6';
local image = 'cassandra:' + version;

function(global, cassandra)
  if cassandra.bundled
  then [
    destinationrule.new(app) +
    metadata.new(app, global.namespace) +
    destinationrule.circuitBreaker(),

    service.new(app, headless=true) +
    metadata.new(app, global.namespace) +
    service.port(9042, name='tcp-cql'),

    destinationrule.new('%s-headless' % app) +
    metadata.new('%s-headless' % app, global.namespace) +
    destinationrule.circuitBreaker(),

    service.new(app, headless=true, onlyReady=false) +
    metadata.new('%s-headless' % app, global.namespace) +
    service.port(7000, name='tcp-cluster'),

    configmap.new() +
    metadata.new(app, global.namespace) +
    configmap.data((import 'cassandra.env.jsonnet')(app)),

    statefulset.new(version=version, replicas=cassandra.replicas, parallel=true, service='%s-headless' % app) +
    metadata.new(app, global.namespace) +
    statefulset.pod(
      pod.new() +
      metadata.new(app) +
      pod.container(
        container.new('copy-config', image) +
        container.command(['/bin/sh', '-c', 'cp -r /etc/cassandra/* /var/lib/cassandra']) +
        container.volume('config', '/var/lib/cassandra') +
        container.resources('10m', '10m', '16Mi', '16Mi'),
        init=true
      ) +
      pod.container(
        container.new(app, image) +
        container.env({
          CASSANDRA_BROADCAST_ADDRESS: { fieldRef: { fieldPath: 'status.podIP' } },
        }) +
        container.envFrom(configmap=app) +
        container.volume('config', '/etc/cassandra') +
        container.volume('data', '/var/lib/cassandra') +
        container.volume('tmp', '/tmp') +
        container.port('tcp-cql', 9042) +
        container.port('tcp-cluster', 7000) +
        container.resources('500m', '2', '3Gi', '3Gi') +
        container.execProbe('readiness', ['/bin/sh', '-c', @'nodetool status | grep -E "^UN\s+$CASSANDRA_BROADCAST_ADDRESS"'], timeout=120) +
        container.execProbe('liveness', ['/bin/sh', '-c', 'nodetool status'], delay=120, timeout=120) +
        container.execHandler('stop', ['/bin/sh', '-c', 'nodetool drain']) +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.volumeEmptyDir('config', '1Mi') +
      pod.volumeEmptyDir('tmp', '1Mi') +
      pod.securityContext({ runAsUser: 999, runAsGroup: 999 }) +
      pod.affinity(global.affinity) +
      pod.tolerations(global.tolerations)
    ) +
    statefulset.volumeClaim('data', '50Gi'),
  ]
  else [
    serviceentry.new() +
    metadata.new(app, global.namespace) +
    serviceentry.host(app) +
    serviceentry.vip(cassandra.internalAddress) +
    serviceentry.endpoint(cassandra.externalAddress) +
    serviceentry.port(app, cassandra.port),
  ]
