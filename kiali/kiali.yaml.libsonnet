function(config) {
  server: { port: 20001 },
  auth: { strategy: 'anonymous' },
  deployment: { accessible_namespaces: ['**'] },

  // TODO: Figure out how these work
  istio_namespace: 'istio-system',
  istio_component_namespaces: {
    grafana: 'istio-system',
    pilot: 'istio-system',
    prometheus: 'istio-system',
    tracing: 'istio-system',
  },

  // TODO: Configure external URLs
  external_services: {
    grafana: {
      url: null,
    },
    istio: {
      url_service_version: 'http://istio-pilot.istio-system:8080/version',
    },
    prometheus: {
      url: 'http://prometheus.istio-system:9090',
    },
    tracing: {
      url: null,
    },
  },
}
