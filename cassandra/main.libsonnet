local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
local destinationrule = import '../templates/destinationrule.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local pod = import '../templates/pod.libsonnet';
local service = import '../templates/service.libsonnet';
local serviceentry = import '../templates/serviceentry.libsonnet';
local statefulset = import '../templates/statefulset.libsonnet';

local app = 'cassandra';
local image = 'cassandra:3.11.6';

function(config)
  local ns = config.cassandra.namespace;
  local cassandra = config.cassandra;
  local vip = cassandra.vip;

  if cassandra.bundled
  then [
    destinationrule.new(app) +
    metadata.new(app, ns=ns) +
    destinationrule.circuit_breaker(),

    service.new(app, headless=true) +
    metadata.new(app, ns=ns) +
    service.port(9042, name='tcp-cql'),

    destinationrule.new('%s-gossip' % app) +
    metadata.new('%s-gossip' % app, ns=ns) +
    destinationrule.circuit_breaker(),

    service.new(app, headless=true, only_ready=false) +
    metadata.new('%s-gossip' % app, ns=ns) +
    service.port(7000, name='tcp-gossip'),

    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data((import 'cassandra.env.libsonnet')(app)),

    statefulset.new(replicas=cassandra.replicas, parallel=true, service='%s-gossip' % app) +
    metadata.new(app, ns=ns) +
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
        container.env_from(configmap=app) +
        container.volume('config', '/etc/cassandra') +
        container.volume('data', '/var/lib/cassandra') +
        container.volume('tmp', '/tmp') +
        container.port('tcp-cql', 9042) +
        container.port('tcp-gossip', 7000) +
        container.resources('500m', '500m', '3Gi', '3Gi') +
        container.exec_probe('readiness', ['/bin/sh', '-c', @'nodetool status | grep -E "^UN\s+$CASSANDRA_BROADCAST_ADDRESS"'], timeout=30) +
        container.exec_probe('liveness', ['/bin/sh', '-c', 'nodetool status'], delay=120, timeout=30) +
        container.exec_handler('stop', ['/bin/sh', '-c', 'nodetool drain']) +
        container.security_context({ readOnlyRootFilesystem: true })
      ) +
      pod.volume_emptydir('config', '1Mi') +
      pod.volume_emptydir('tmp', '1Mi') +
      pod.security_context({ runAsUser: 999, runAsGroup: 999 }) +
      pod.node_selector(cassandra.node_selector) +
      pod.tolerations(cassandra.node_tolerations)
    ) +
    statefulset.volume_claim('data', '50Gi'),
  ]
  else [
    serviceentry.new() +
    metadata.new(app, ns=ns) +
    serviceentry.host(app) +
    serviceentry.vip(vip.internal_address) +
    serviceentry.endpoint(vip.external_address) +
    serviceentry.port(app, vip.port),
  ]
