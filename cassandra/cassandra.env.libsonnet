function(app) {
  CASSANDRA_CLUSTER_NAME: 'Kubernetes',
  CASSANDRA_LISTEN_ADDRESS: '127.0.0.1',
  CASSANDRA_SEEDS: '%(app)s-0.%(app)s-gossip' % { app: app },
  CASSANDRA_ENDPOINT_SNITCH: 'GossipingPropertyFileSnitch',
  MAX_HEAP_SIZE: '4G',
  HEAP_NEWSIZE: '500M',
}
