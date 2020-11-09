function(global, grafana, jaeger) {
  server: { port: 20001 },
  auth: { strategy: 'anonymous' },
  deployment: { accessible_namespaces: ['**'] },
  kubernetes_config: { excluded_workloads: [] },

  external_services: {
    grafana: {
      url: '%s://%s' % [if global.tls then 'https' else 'http', grafana.externalAddress],
    },
    istio: {
      url_service_version: 'http://istiod.istio-system:15014/version',
    },
    prometheus: {
      url: 'http://prometheus.%s:9090' % global.namespace,
    },
    tracing: {
      in_cluster_url: 'http://jaeger-query.%s:16686' % global.namespace,
      url: '%s://%s' % [if global.tls then 'https' else 'http', jaeger.externalAddress],
    },
  },
}
