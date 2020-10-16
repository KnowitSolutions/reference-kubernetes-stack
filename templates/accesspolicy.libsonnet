{
  new(gateway, provider):: {
    apiVersion: 'krsdev.app/v1',
    kind: 'AccessPolicy',
    spec: {
      gateway: gateway,
      oidc: { provider: provider },
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
