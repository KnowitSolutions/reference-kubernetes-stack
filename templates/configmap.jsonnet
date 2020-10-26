{
  new():: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
  },

  data(data):: {
    data+: data,
  },
}
