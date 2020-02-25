{
  new(name, ns=null):: {
    metadata+: {
      name: name,
      [if ns != null then 'namespace']: ns,
    },
  },

  label(key, value):: self.labels({ [key]: value }),

  labels(labels):: {
    metadata+: {
      labels+: labels,
    },
  },
}
