{
  new(app, image):: {
    name: app,
    image: image,
  },

  command(command):: {
    command: command,
  },

  env(env):: {
    env+: [
      { name: key, value: env[key] }
      for key in std.objectFields(env)
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

  resources(cpu_request=null, cpu_limit=null, memory_request=null, memory_limit=null):: {
    resources: {
      requests: {
        [if cpu_request != null then 'cpu']: cpu_request,
        [if memory_request != null then 'memory']: memory_request,
      },
      limits: {
        [if cpu_limit != null then 'cpu']: cpu_limit,
        [if memory_limit != null then 'memory']: memory_limit,
      },
    },
  },

  http_probe(type, path, port='http'):: {
    [type + 'Probe']: {
      httpGet: {
        path: path,
        port: port,
      },
    },
  },

  volume(name, path, sub_path=null):: {
    volumeMounts+: [
      {
        name: name,
        mountPath: path,
        [if sub_path != null then 'subPath']: sub_path,
      },
    ],
  },
}