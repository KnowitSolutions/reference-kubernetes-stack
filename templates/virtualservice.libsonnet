{
  new():: {
    apiVersion: 'networking.istio.io/v1alpha3',
    kind: 'VirtualService',
  },

  host(host):: {
    spec+: {
      hosts+: [
        host,
      ],
    },
  },

  gateway(gateway):: {
    spec+: {
      gateways+: [
        gateway,
      ],
    },
  },

  route(destination, port=null):: {
    spec+: {
      http+: [
        {
          route: [
            {
              destination: {
                host: destination,
                [if port != null then 'port']: { number: port },
              },
            },
          ],
        },
      ],
    },
  },
}
