function(config) {
  cassandra: {
    servers: 'cassandra.db',
    keyspace: 'jaeger',
  },
  collector: {
    zipkin: {
      'http-port': 9411,
    },
  },
}
