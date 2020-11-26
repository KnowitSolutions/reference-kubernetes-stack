local metadata = import 'metadata.jsonnet';

{
  new(version):: {
    local daemonset = self,
    apiVersion: 'apps/v1',
    kind: 'DaemonSet',
    metadata: (
      metadata.label('app', daemonset.metadata.name) +
      metadata.label('version', version)
    ).metadata,
    spec: {
      selector: { matchLabels: { app: daemonset.metadata.name } },
    },
  },

  pod(pod):: {
    local daemonset = self,
    spec+: {
      template: pod + metadata.labels(daemonset.metadata.labels),
    },
  },
}
