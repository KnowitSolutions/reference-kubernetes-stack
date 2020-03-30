function(config) {
  local cassandra = config.loki.cassandra,

  auth_enabled: false,

  server: {
    http_listen_port: 8080,
  },

  // TODO: Fix high availability
  ingester: {
    lifecycler: {
      ring: {
        kvstore: {
          store: 'inmemory',
        },
        replication_factor: 1,
      },
    },
  },

  schema_config: {
    configs: [
      {
        chunks: {
          period: '168h',
          prefix: 'chunk_',
        },
        from: '2020-01-01',
        index: {
          period: '168h',
          prefix: 'index_',
        },
        schema: 'v11',
        store: 'cassandra',
      },
    ],
  },

  storage_config: {
    cassandra: {
      addresses: cassandra.address,
      port: cassandra.port,
      keyspace: cassandra.keyspace,
      auth: cassandra.username != null && cassandra.password != null,
      [if cassandra.username != null then 'username']: cassandra.username,
      [if cassandra.password != null then 'password']: cassandra.password,
    },
  },

  limits_config: {
    enforce_metric_name: false,
  },

  table_manager: {
    retention_deletes_enabled: true,
    retention_period: '672h',
  },

  chunk_store_config: {
    max_look_back_period: '672h',
  },
}
