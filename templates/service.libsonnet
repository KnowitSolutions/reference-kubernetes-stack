{
  new(app, headless=false):: {
    apiVersion: 'v1',
    kind: 'Service',
    spec: {
      selector: {
        app: app,
      },
      type: 'ClusterIP',
      [if headless then 'clusterIP']: 'None',
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
