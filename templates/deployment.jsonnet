local metadata = import 'metadata.jsonnet';

{
  new(version, replicas=1):: {
    local deployment = self,
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: (
      metadata.label('app', deployment.metadata.name) +
      metadata.label('version', version)
    ).metadata,
    spec: {
      replicas: replicas,
      selector: { matchLabels: { app: deployment.metadata.name } },
    },
  },

  pod(pod):: {
    local deployment = self,
    spec+: {
      template: pod + metadata.labels(deployment.metadata.labels),
    },
  },
}
