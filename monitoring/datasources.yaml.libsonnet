function(config) {
  apiVersion: 1,
  datasources: [
    {
      name: 'Prometheus',
      type: 'prometheus',
      access: 'proxy',
      url: 'http://prometheus.%s:9090' % [config.prometheus.namespace],
    },
  ],
}
