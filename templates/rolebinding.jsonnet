{
  new(cluster=false):: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: if cluster then 'ClusterRoleBinding' else 'RoleBinding',
  },

  role(name, cluster=false):: {
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: if cluster then 'ClusterRole' else 'Role',
      name: name,
    },
  },

  subject(kind, name, ns=null): {
    local isApi = std.member(['Group', 'User'], name),
    subjects+: [
      {
        [if isApi then 'apiGroup']: 'rbac.authorization.k8s.io',
        kind: kind,
        name: name,
        [if ns != null then 'namespace']: ns,
      },
    ],
  },
}
