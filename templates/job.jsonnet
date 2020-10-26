local metadata = import 'metadata.jsonnet';

{
  new():: {
    apiVersion: 'batch/v1',
    kind: 'Job',
  },

  pod(pod):: {
    spec+: {
      template: pod {
        spec+: {
          restartPolicy: 'OnFailure',
        },
      },
    },
  },
}
