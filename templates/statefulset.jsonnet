local metadata = import 'metadata.jsonnet';

{
  new(version, replicas=1, parallel=false, service=null):: {
    local statefulset = self,
    apiVersion: 'apps/v1',
    kind: 'StatefulSet',
    metadata: (
      metadata.label('app', statefulset.metadata.name) +
      metadata.label('version', version)
    ).metadata,
    spec: {
      serviceName: if service == null then statefulset.metadata.name else service,
      replicas: replicas,
      podManagementPolicy: if parallel then 'Parallel' else 'OrderedReady',
      selector: { matchLabels: { app: statefulset.metadata.name } },
    },
  },

  pod(pod):: {
    local statefulset = self,
    spec+: {
      template: pod + metadata.labels(statefulset.metadata.labels),
    },
  },

  volumeClaim(name, size):: {
    spec+: {
      volumeClaimTemplates+: [
        metadata.new(name) + {
          spec: {
            accessModes: ['ReadWriteOnce'],
            resources: { requests: { storage: size } },
          },
        },
      ],
    },
  },
}
