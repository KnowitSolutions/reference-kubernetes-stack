{
  new():: {
    apiVersion: 'v1',
    kind: 'Secret',
    type: 'Opaque',
  },

  data(data):: {
    stringData+: data,
  },
}
