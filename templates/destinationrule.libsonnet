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
      trafficPolicy: {
        tls: { mode: if mtls then 'ISTIO_MUTUAL' else 'DISABLE' },
      },
    },
  },

  sticky():: {
    spec+: {
      trafficPolicy+: {
        loadBalancer: {
          consistentHash: { useSourceIp: true },
        },
      },
    },
  },
}
