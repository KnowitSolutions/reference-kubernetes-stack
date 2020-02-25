local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
local gateway = import '../templates/gateway.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local pod = import '../templates/pod.libsonnet';
local service = import '../templates/service.libsonnet';
local statefulset = import '../templates/statefulset.libsonnet';
local virtualservice = import '../templates/virtualservice.libsonnet';

local app = 'grafana';
local image = 'grafana/grafana:6.6.1';

function(config)
  local ns = config.grafana.namespace;
  local grafana = config.grafana;
  local keycloak = config.keycloak;

  [
    gateway.new(grafana.external_address) +
    metadata.new(app, ns=ns),

    virtualservice.new() +
    metadata.new(app, ns=ns) +
    virtualservice.host(grafana.external_address) +
    virtualservice.gateway(app) +
    virtualservice.route(app),

    service.new(app) +
    metadata.new(app, ns=ns) +
    service.port(3000),

    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'grafana.ini': std.manifestIni((import 'grafana.ini.libsonnet')(config)),
      'datasources.yaml': std.manifestYamlDoc((import 'datasources.yaml.libsonnet')(config)),
    }),

    statefulset.new() +
    metadata.new(app, ns=ns) +
    statefulset.pod(
      pod.new() +
      pod.container(
        container.new(app, image) +
        container.port('http', 3000) +
        container.volume('config', '/etc/grafana') +
        container.volume('data', '/var/lib/grafana') +
        container.resources('100m', '500m', '100Mi', '2500Mi')
      ) +
      pod.volume_configmap('config', configmap=app, items={
        'grafana.ini': 'grafana.ini',
        'datasources.yaml': 'provisioning/datasources/datasources.yaml',
      }) +
      pod.security_context({ runAsUser: 472 })
    ) +
    statefulset.volume_claim('data', '10Gi'),
  ]
