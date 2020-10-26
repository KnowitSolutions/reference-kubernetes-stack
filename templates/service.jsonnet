{
  new(app, headless=false, onlyReady=true):: {
    apiVersion: 'v1',
    kind: 'Service',
    spec: {
      selector: {
        app: app,
      },
      type: 'ClusterIP',
      [if headless then 'clusterIP']: 'None',
      publishNotReadyAddresses: !onlyReady,
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
