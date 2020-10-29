function(config) {
  local cassandra = config.loki.cassandra,

  auth_enabled: false,

  server: {
    http_listen_port: 8080,
  },

  distributor: {
    ring: {
      kvstore: { store: 'memberlist' },
    },
  },

  ingester: {
    lifecycler: {
      ring: {
        kvstore: { store: 'memberlist' },
        replication_factor: 1,
      },
    },
  },

  memberlist: {
    randomize_node_name: false,
    join_members: ['loki-gossip:7946'],
  },

  schema_config: {
    configs: [
      {
        from: '2020-01-01',
        store: 'cassandra',
        schema: 'v11',
        index: { prefix: 'index_', period: '168h' },
        chunks: { prefix: 'chunk_', period: '168h' },
      },
    ],
  },

  storage_config: {
    cassandra: {
      addresses: cassandra.address,
      port: cassandra.port,
      keyspace: cassandra.keyspace,
      auth: cassandra.username != null && cassandra.password != null,
      SSL: cassandra.tls.enabled,
      host_verification: cassandra.tls.hostnameValidation,
      connect_timeout: cassandra.timeout,
      timeout: cassandra.timeout,
    },
  },

  limits_config: {
    enforce_metric_name: false,
    max_streams_per_user: 0,
  },

  table_manager: {
    retention_deletes_enabled: true,
    retention_period: '672h',
  },

  chunk_store_config: {
    max_look_back_period: '672h',  // TODO: This is probably wrong, as default is documented as 30s. Might cause slowdowns?
  },
}
