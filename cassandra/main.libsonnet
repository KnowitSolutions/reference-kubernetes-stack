local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
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
    service.new(app, headless=true) +
    metadata.new(app, ns=ns) +
    service.port(9042, name='tcp-cql'),

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
        container.new(app, image) +
        container.env({
          CASSANDRA_BROADCAST_ADDRESS: { fieldRef: { fieldPath: 'status.podIP' } },
        }) +
        container.env_from(configmap=app) +
        container.volume('data', '/var/lib/cassandra') +
        container.port('tcp-cql', 9042) +
        container.port('tcp-gossip', 7000) +
        container.resources('500m', '500m', '3Gi', '3Gi') +
        container.exec_probe('readiness', ['/bin/sh', '-c', @'nodetool status | grep -E "^UN\s+$CASSANDRA_BROADCAST_ADDRESS"'], timeout=30) +
        container.exec_probe('liveness', ['/bin/sh', '-c', 'nodetool status'], delay=120, timeout=30) +
        container.exec_handler('stop', ['/bin/sh', '-c', 'nodetool drain'])
      ) +
      pod.security_context({ runAsUser: 999, runAsGroup: 999 }),
    ) +
    statefulset.volume_claim('data', '10Gi'),
  ]
  else [
    serviceentry.new() +
    metadata.new(app, ns=ns) +
    serviceentry.host(app) +
    serviceentry.vip(vip.internal_address) +
    serviceentry.endpoint(vip.external_address) +
    serviceentry.port(app, vip.port),
  ]
