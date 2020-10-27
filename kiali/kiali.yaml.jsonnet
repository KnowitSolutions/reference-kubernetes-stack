function(config) {
  local grafana = config.grafana,
  local jaeger = config.jaeger,

  server: { port: 20001 },
  auth: { strategy: 'anonymous' },
  deployment: { accessible_namespaces: ['**'] },
  kubernetes_config: { excluded_workloads: [] },

  external_services: {
    grafana: {
      url: '%s://%s' % [grafana.externalProtocol, grafana.externalAddress],
    },
    istio: {
      url_service_version: 'http://istiod.istio-system:15014/version',
    },
    prometheus: {
      url: 'http://prometheus:9090',
    },
    tracing: {
      in_cluster_url: 'http://jaeger-query.%s:16686' % jaeger.namespace,
      url: '%s://%s' % [jaeger.externalProtocol, jaeger.externalAddress],
    },
  },
}
