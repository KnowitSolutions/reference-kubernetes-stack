{
  new(gateway):: {
    apiVersion: 'krsdev.app/v1',
    kind: 'AccessPolicy',
    spec: {
      gateway: gateway,
      realm: 'master',
    },
  },

  credentials(secret):: {
    spec+: {
      oidc+: {
        credentialsSecretRef: { name: secret },
      },
    },
  },
}
