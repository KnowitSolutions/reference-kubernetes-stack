{
  new(issuer):: {
    apiVersion: 'krsdev.app/v1',
    kind: 'OpenIDProvider',
    spec: {
      issuer: issuer,
    },
  },

  role_mapping(path):: {
    spec+: {
      roleMappings+: [{
        path: path,
      }],
    },
  },
}
