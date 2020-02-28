{
  new(name, ns=null):: {
    metadata+: {
      name: name,
      [if ns != null then 'namespace']: ns,
    },
  },

  annotations(annotations):: {
    metadata+: {
      annotations+: annotations,
    },
  },

  label(key, value):: self.labels({ [key]: value }),

  labels(labels):: {
    metadata+: {
      labels+: labels,
    },
  },
}
