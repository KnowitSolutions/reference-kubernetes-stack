local metadata = import 'metadata.libsonnet';

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

  volume_emptydir(name, size):: {
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

  volume_hostpath(name, path, type='Directory'):: {
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

  volume_configmap(name, configmap, items=null, default_mode=null):: {
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
            [if default_mode != null then 'defaultMode']: default_mode,
          },
        },
      ],
    },
  },

  service_account(service_account):: {
    spec+: {
      serviceAccountName: service_account,
    },
  },

  security_context(security_context):: {
    spec+: {
      securityContext: security_context,
    },
  },

  new_affinity(labels):: {
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

  new_tolerations(tolerations):: [
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
