local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
local job = import '../templates/job.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local pod = import '../templates/pod.libsonnet';

local app = 'keycloak-initialize';
local image = 'jboss/keycloak:9.0.0';

function(config)
  local ns = config.keycloak.namespace;

  [
    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'initialize.sh': (import 'initialize.sh.libsonnet')(config),
    }),

    job.new() +
    metadata.new(app, ns=ns) +
    job.pod(
      pod.new() +
      metadata.new(app) +
      pod.container(
        container.new(app, image) +
        container.command(['/initialize.sh']) +
        container.volume('script', '/initialize.sh', sub_path='initialize.sh') +
        container.resources('1000m', '1000m', '256Mi', '256Mi')
      ) +
      pod.security_context({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.volume_configmap('script', app, default_mode=std.parseOctal('555'))
    ),
  ]
