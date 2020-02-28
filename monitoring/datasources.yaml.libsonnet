function(config) {
  apiVersion: 1,
  datasources: [
    {
      name: 'Prometheus',
      type: 'prometheus',
      access: 'proxy',
      url: 'http://prometheus.istio-system:9090',
    },
  ],
}
