local metadata = import 'metadata.jsonnet';

{
  new():: {
    spec: {
      nodeSelector: { 'kubernetes.io/os': 'linux' },
    },
  },

  container(container, init=false):: {
    spec+: {
      [if init then 'initContainers' else 'containers']+: [container],
    },
  },

  volumeEmptyDir(name, size):: {
    spec+: {
      volumes+: [
        {
          name: name,
          emptyDir: {
            sizeLimit: size,
          },
        },
      ],
    },
  },

  volumeHostPath(name, path, type='Directory'):: {
    spec+: {
      volumes+: [
        {
          name: name,
          hostPath: {
            path: path,
            type: type,
          },
        },
      ],
    },
  },

  volumeConfigMap(name, configmap, items=null, defaultMode=null, optional=false):: {
    spec+: {
      volumes+: [
        {
          name: name,
          configMap: {
            name: configmap,
            [if items != null then 'items']: [
              { key: key, path: items[key] }
              for key in std.objectFields(items)
            ],
            [if defaultMode != null then 'defaultMode']: defaultMode,
            optional: optional,
          },
        },
      ],
    },
  },

  serviceAccount(serviceAccount):: {
    spec+: {
      serviceAccountName: serviceAccount,
    },
  },

  securityContext(securityContext):: {
    spec+: {
      securityContext: securityContext,
    },
  },

  host(pid=false, network=false):: {
    spec+: {
      hostPID: pid,
      hostNetwork: network,
    },
  },

  newAffinity(labels):: {
    nodeAffinity: {
      requiredDuringSchedulingIgnoredDuringExecution: {
        nodeSelectorTerms: [{
          matchExpressions: [
            {
              local split = std.splitLimit(label, '=', 1),
              assert std.length(split) == 2 : 'Invalid label: %s' % label,
              key: split[0],
              operator: 'In',
              values: [split[1]],
            }
            for label in labels
          ],
        }],
      },
    },
  },

  affinity(affinity):: {
    spec+: {
      affinity: affinity,
    },
  },

  newTolerations(tolerations):: [
    {
      local left = std.splitLimit(toleration, '=', 1),
      local right = std.splitLimit(left[1], ':', 1),
      assert std.length(left) == 2 : 'Invalid toleration: %s' % toleration,
      assert std.length(right) == 2 : 'Invalid toleration: %s' % toleration,
      local split = [left[0], right[0], right[1]],
      key: split[0],
      operator: 'Equal',
      value: split[1],
      effect: split[2],
    }
    for toleration in tolerations
  ],

  tolerations(tolerations):: {
    spec+: {
      tolerations: tolerations,
    },
  },
}
