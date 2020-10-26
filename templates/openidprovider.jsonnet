{
  new(issuer):: {
    apiVersion: 'krsdev.app/v1',
    kind: 'OpenIDProvider',
    spec: {
      issuer: issuer,
    },
  },

  roleMapping(path):: {
    spec+: {
      roleMappings+: [{
        path: path,
      }],
    },
  },
}
