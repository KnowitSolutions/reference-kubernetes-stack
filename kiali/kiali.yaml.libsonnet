function(config) {
  server: { port: 20001 },
  auth: { strategy: 'anonymous' },
  deployment: { accessible_namespaces: ['**'] },

  external_services: {
    grafana: {
      url: 'http://grafana.localhost',
    },
    istio: {
      url_service_version: 'http://istio-pilot.istio-system:8080/version',
    },
    prometheus: {
      url: 'http://prometheus.istio-system:9090',
    },
    tracing: {
      in_cluster_url: 'http://jaeger-query.monitoring:16686',
      url: 'http://jaeger.localhost',
    },
  },
}
