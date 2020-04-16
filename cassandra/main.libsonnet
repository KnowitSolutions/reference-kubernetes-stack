local container = import '../templates/container.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local pod = import '../templates/pod.libsonnet';
local service = import '../templates/service.libsonnet';
local statefulset = import '../templates/statefulset.libsonnet';

local app = 'cassandra';
local image = 'cassandra:3.11.6';

function(config)
  local ns = config.cassandra.namespace;
  local cassandra = config.cassandra;

  [
    service.new(app, headless=true) +
    metadata.new(app, ns=ns) +
    service.port(9042, name='tcp-cql'),

    service.new(app, headless=true, only_ready=false) +
    metadata.new('%s-gossip' % app, ns=ns) +
    service.port(7000, name='tcp-gossip'),

    statefulset.new(replicas=cassandra.replicas, parallel=true, service='%s-gossip' % app) +
    metadata.new(app, ns=ns) +
    statefulset.pod(
      pod.new() +
      metadata.new(app) +
      pod.container(
        container.new(app, image) +
        container.env({
          CASSANDRA_CLUSTER_NAME: 'Kubernetes',
          CASSANDRA_LISTEN_ADDRESS: '127.0.0.1',
          CASSANDRA_BROADCAST_ADDRESS: { fieldRef: { fieldPath: 'status.podIP' } },
          CASSANDRA_SEEDS: '%(app)s-0.%(app)s-gossip' % { app: app },
          CASSANDRA_ENDPOINT_SNITCH: 'GossipingPropertyFileSnitch',
          MAX_HEAP_SIZE: '4G',
          HEAP_NEWSIZE: '500M',
        }) +
        container.volume('data', '/var/lib/cassandra') +
        container.port('tcp-cql', 9042) +
        container.port('tcp-gossip', 7000) +
        container.resources('500m', '500m', '5Gi', '5Gi') +
        container.exec_probe('readiness', ['/bin/sh', '-c', @'nodetool status | grep -E "^UN\s+$CASSANDRA_BROADCAST_ADDRESS"'], timeout=30) +
        container.exec_probe('liveness', ['/bin/sh', '-c', 'nodetool status'], delay=120, timeout=30) +
        container.exec_handler('stop', ['/bin/sh', '-c', 'nodetool drain'])
      ) +
      pod.security_context({ runAsUser: 999, runAsGroup: 999 }),
    ) +
    statefulset.volume_claim('data', '10Gi'),
  ]
