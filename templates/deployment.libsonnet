local metadata = import 'metadata.libsonnet';

{
  new(replicas=1):: {
    local deployment = self,
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: (
      metadata.label('app', deployment.metadata.name) +
      metadata.label('version', 'master')
    ).metadata,
    spec: {
      replicas: replicas,
      selector: { matchLabels: deployment.metadata.labels },
    },
  },

  pod(pod):: {
    local deployment = self,
    spec+: {
      template: pod + metadata.labels(deployment.spec.selector.matchLabels),
    },
  },
}
