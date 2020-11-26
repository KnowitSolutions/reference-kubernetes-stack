function(global, kiali, keycloak, grafana, jaeger) {
  server: {
    port: 20001,
    web_port: if global.tls then 443 else 80,
  },

  auth: {
    strategy: 'openid',
    openid: {
      client_id: kiali.oidc.clientId,
      disable_rbac: true,
      authorization_endpoint:
        (if global.tls then 'https://' else 'http://') +
        keycloak.externalAddress +
        '/auth/realms/master/protocol/openid-connect/auth',
      username_claim: 'preferred_username',
    },
  },

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
