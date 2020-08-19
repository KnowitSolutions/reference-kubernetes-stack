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

  node_selector(labels):: {
    local split = function(label)
      local split = std.splitLimit(label, '=', 1);
      assert std.length(split) == 2 : 'Invalid label: %s' % label;
      split,
    local key = function(label) split(label)[0],
    local value = function(label) split(label)[1],

    spec+: {
      nodeSelector: {
        [key(label)]: value(label)
        for label in labels
      },
    },
  },

  tolerations(tolerations):: {
    local split = function(toleration)
      local left = std.splitLimit(toleration, '=', 1);
      assert std.length(left) == 2 : 'Invalid toleration: %s' % toleration;
      local right = std.splitLimit(left[1], ':', 1);
      assert std.length(right) == 2 : 'Invalid toleration: %s' % toleration;
      [left[0], right[0], right[1]],
    local key = function(toleration) split(toleration)[0],
    local value = function(toleration) split(toleration)[1],
    local effect = function(toleration) split(toleration)[2],

    spec+: {
      tolerations: [
        {
          key: key(toleration),
          operator: 'Equal',
          value: value(toleration),
          effect: effect(toleration),
        }
        for toleration in tolerations
      ],
    },
  },
}
