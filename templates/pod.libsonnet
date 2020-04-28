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
}
