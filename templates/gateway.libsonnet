{
  new(host):: {
    apiVersion: 'networking.istio.io/v1alpha3',
    kind: 'Gateway',
    spec: {
      selector: {
        istio: 'ingressgateway',
      },
      servers: [
        {
          hosts: [
            host,
          ],
          port: {
            name: 'http',
            protocol: 'HTTP',
            number: 80,
          },
        },
      ],
    },
  },
}
