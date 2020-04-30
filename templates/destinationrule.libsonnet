{
  new(host):: {
    apiVersion: 'networking.istio.io/v1alpha3',
    kind: 'DestinationRule',
    spec: {
      host: host,
      trafficPolicy: {
        tls: { mode: 'ISTIO_MUTUAL' },
      },
    },
  },

  mtls(mtls):: {
    spec+: {
      trafficPolicy+: {
        tls: { mode: if mtls then 'ISTIO_MUTUAL' else 'DISABLE' },
      },
    },
  },

  circuit_breaker():: {
    spec+: {
      trafficPolicy+: {
        outlierDetection: {
          consecutiveGatewayErrors: 5,
          interval: '1m',
          baseEjectionTime: '5m',
          maxEjectionPercent: 100,
        },
      },
    },
  },
}
