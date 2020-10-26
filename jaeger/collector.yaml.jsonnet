function(config) {
  local cassandra = config.jaeger.cassandra,

  cassandra: {
    servers: cassandra.address,
    port: cassandra.port,
    keyspace: cassandra.keyspace,
    tls: {
      enabled: cassandra.tls.enabled,
      'verify-host': cassandra.tls.hostname_validation,
    },
    'connect-timeout': cassandra.timeout,
    timeout: cassandra.timeout,
  },

  collector: {
    zipkin: {
      'http-port': 9411,
    },
  },
}
