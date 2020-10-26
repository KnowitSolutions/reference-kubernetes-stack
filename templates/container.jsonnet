{
  new(app, image):: {
    name: app,
    image: image,
  },

  command(command):: {
    command: command,
  },

  args(args):: {
    args: args,
  },

  env(env):: {
    env+: [
      { name: key } +
      if std.isString(env[key])
      then { value: env[key] }
      else { valueFrom: env[key] }
      for key in std.objectFields(env)
    ],
  },

  envFrom(configmap=null, secret=null, prefix=null):: {
    envFrom+: [
      {
        [if configmap != null then 'configMapRef']: { name: configmap },
        [if secret != null then 'secretRef']: { name: secret },
        [if prefix != null then 'prefix']: prefix,
      },
    ],
  },

  port(protocol, port):: {
    ports+: [
      {
        name: protocol,
        containerPort: port,
      },
    ],
  },

  resources(cpuRequest=null, cpuLimit=null, memoryRequest=null, memoryLimit=null):: {
    resources: {
      requests: {
        [if cpuRequest != null then 'cpu']: cpuRequest,
        [if memoryRequest != null then 'memory']: memoryRequest,
      },
      limits: {
        [if cpuLimit != null then 'cpu']: cpuLimit,
        [if memoryLimit != null then 'memory']: memoryLimit,
      },
    },
  },

  execProbe(type, command, delay=null, timeout=10):: {
    [type + 'Probe']: {
      [if delay != null then 'initialDelaySeconds']: delay,
      timeoutSeconds: timeout,
      exec: {
        command: command,
      },
    },
  },

  httpProbe(type, path, port='http', delay=null, timeout=10):: {
    [type + 'Probe']: {
      [if delay != null then 'initialDelaySeconds']: delay,
      timeoutSeconds: timeout,
      httpGet: {
        path: path,
        port: port,
      },
    },
  },

  execHandler(type, command):: {
    lifecycle+: {
      [if type == 'start' then 'postStart'
      else if type == 'stop' then 'preStop']: {
        exec: {
          command: command,
        },
      },
    },
  },

  volume(name, path, subPath=null, readOnly=false):: {
    volumeMounts+: [
      {
        name: name,
        mountPath: path,
        [if subPath != null then 'subPath']: subPath,
        readOnly: readOnly,
      },
    ],
  },

  securityContext(securityContext):: {
    securityContext: securityContext,
  },
}
