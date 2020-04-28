local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
local job = import '../templates/job.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local pod = import '../templates/pod.libsonnet';

local app = 'keycloak';
local app_init = 'keycloak-initialize';
local app_grafana = 'grafana';
local app_kiali = 'kiali';
local app_jaeger = 'jaeger';
local image = 'jboss/keycloak:9.0.0';

function(config)
  local ns = config.keycloak.namespace;

  [
    configmap.new() +
    metadata.new(app_init, ns=ns) +
    configmap.data({
      'initialize.sh': (import 'initialize.sh.libsonnet')(config),
    }),

    job.new() +
    metadata.new(app_init, ns=ns) +
    job.pod(
      pod.new() +
      metadata.new(app_init) +
      pod.container(
        container.new(app_init, image) +
        container.command(['/initialize.sh']) +
        container.env_from(secret=app) +
        container.env_from(secret=app_grafana, prefix='GRAFANA_') +
        container.env_from(secret=app_kiali, prefix='KIALI_') +
        container.env_from(secret=app_jaeger, prefix='JAEGER_') +
        container.volume('script', '/initialize.sh', sub_path='initialize.sh') +
        container.resources('1000m', '1000m', '256Mi', '256Mi')
        // TODO: container.security_context({ readOnlyRootFilesystem: true })
      ) +
      pod.security_context({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.volume_configmap('script', app_init, default_mode=std.parseOctal('555'))
    ),
  ]
