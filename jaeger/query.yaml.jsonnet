function(jaeger, cassandra) {
  cassandra: {
    servers: cassandra.address,
    port: cassandra.port,
    keyspace: jaeger.keyspace,
    tls: {
      enabled: cassandra.tls.enabled,
      'verify-host': cassandra.tls.hostnameValidation,
    },
    'connect-timeout': cassandra.timeout,
    timeout: cassandra.timeout,
  },
}
