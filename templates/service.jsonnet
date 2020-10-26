{
  new(app, headless=false, only_ready=true):: {
    apiVersion: 'v1',
    kind: 'Service',
    spec: {
      selector: {
        app: app,
      },
      type: 'ClusterIP',
      [if headless then 'clusterIP']: 'None',
      publishNotReadyAddresses: !only_ready,
    },
  },

  port(port, name='http'):: {
    spec+: {
      ports+: [
        {
          port: port,
          name: name,
          targetPort: name,
        },
      ],
    },
  },
}
