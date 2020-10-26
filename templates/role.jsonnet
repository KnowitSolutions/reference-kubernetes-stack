{
  new(cluster=false):: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: if cluster then 'ClusterRole' else 'Role',
  },

  rule(rule):: {
    rules+: [rule],
  },
}
