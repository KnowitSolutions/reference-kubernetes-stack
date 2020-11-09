local configmap = import '../templates/configmap.jsonnet';
local container = import '../templates/container.jsonnet';
local job = import '../templates/job.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local pod = import '../templates/pod.jsonnet';

local app = 'keycloak';
local appInit = 'keycloak-initialize';
local appGrafana = 'grafana';
local appKiali = 'kiali';
local appJaeger = 'jaeger';
local image = 'jboss/keycloak:9.0.0';

function(global, keycloak, grafana, kiali, jaeger)
  [
    configmap.new() +
    metadata.new(appInit, global.namespace) +
    configmap.data({
      'initialize.sh': (import 'initialize.sh.jsonnet')(global, grafana, kiali, jaeger),
    }),

    job.new() +
    metadata.new(appInit, global.namespace) +
    job.pod(
      pod.new() +
      metadata.new(appInit) +
      pod.container(
        container.new(appInit, image) +
        container.command(['/initialize.sh']) +
        container.envFrom(secret=app) +
        container.envFrom(secret=appGrafana, prefix='GRAFANA_') +
        container.envFrom(secret=appKiali, prefix='KIALI_') +
        container.envFrom(secret=appJaeger, prefix='JAEGER_') +
        container.volume('script', '/initialize.sh', subPath='initialize.sh') +
        container.resources('1000m', '1000m', '256Mi', '256Mi')
        // TODO: container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.securityContext({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.volumeConfigMap('script', appInit, defaultMode=std.parseOctal('555')) +
      pod.affinity(global.affinity) +
      pod.tolerations(global.tolerations)
    ),
  ]
