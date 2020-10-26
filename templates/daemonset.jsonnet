local metadata = import 'metadata.jsonnet';

{
  new():: {
    local daemonset = self,
    apiVersion: 'apps/v1',
    kind: 'DaemonSet',
    metadata: (
      metadata.label('app', daemonset.metadata.name) +
      metadata.label('version', 'master')
    ).metadata,
    spec: {
      selector: { matchLabels: daemonset.metadata.labels },
    },
  },

  pod(pod):: {
    local daemonset = self,
    spec+: {
      template: pod + metadata.labels(daemonset.spec.selector.matchLabels),
    },
  },
}
