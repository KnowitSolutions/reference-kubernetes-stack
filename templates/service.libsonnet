{
  new(app):: {
    apiVersion: 'v1',
    kind: 'Service',
    spec: {
      selector: {
        app: app,
      },
      type: 'ClusterIP',
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
