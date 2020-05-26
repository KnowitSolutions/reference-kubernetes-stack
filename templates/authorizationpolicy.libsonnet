local metadata = import 'metadata.libsonnet';

{
  new(labels):: {
    apiVersion: 'security.istio.io/v1beta1',
    kind: 'AuthorizationPolicy',
    spec: {
      selector: {
        matchLabels: labels,
      },
    },
  },

  rule(rule):: {
    spec+: {
      rules+: [rule],
    },
  },

  from(source):: {
    from+: [{ source: source }],
  },

  to(operation):: {
    to+: [{ operation: operation }],
  },

  allow(allow):: {
    spec+: {
      action: if allow then 'ALLOW' else 'DENY',
    },
  },
}
