function(config) {
  local cassandra = config.jaeger.cassandra,

  cassandra: {
    servers: cassandra.address,
    port: cassandra.port,
    keyspace: cassandra.keyspace,
    [if cassandra.username != null then 'username']: cassandra.username,
    [if cassandra.password != null then 'password']: cassandra.password,
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
