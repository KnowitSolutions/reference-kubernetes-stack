{
  new(host, tls=false):: {
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
      ] + (if tls then [
             {
               hosts: [
                 host,
               ],
               port: {
                 name: 'https',
                 protocol: 'HTTPS',
                 number: 443,
               },
               tls: {
                 mode: 'SIMPLE',
                 credentialName: host,
               },
             },
           ] else []),
    },
  },
}
