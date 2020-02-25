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
