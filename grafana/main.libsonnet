local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
local destinationrule = import '../templates/destinationrule.libsonnet';
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
    destinationrule.new('prometheus.istio-system.svc.cluster.local') +
    metadata.new('prometheus-istio-system', ns=ns) +
    destinationrule.mtls(false),

    gateway.new(grafana.external_address) +
    metadata.new(app, ns=ns),

    virtualservice.new() +
    metadata.new(app, ns=ns) +
    virtualservice.host(grafana.external_address) +
    virtualservice.gateway(app) +
    virtualservice.redirect(exact='/metrics', path='/') +
    virtualservice.route(app),

    service.new(app) +
    metadata.new(app, ns=ns) +
    service.port(3000),

    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'grafana.ini': std.manifestIni((import 'grafana.ini.libsonnet')(config)),
      'datasources.yaml': importstr 'datasources.yaml',
      'dashboards.yaml': importstr 'dashboards.yaml',
      'container-overview.json': importstr 'dashboards/container-overview.json',
      'pod-overview.json': importstr 'dashboards/pod-overview.json',
      'resource-overview.json': importstr 'dashboards/resource-overview.json',
    }),

    statefulset.new() +
    metadata.new(app, ns=ns) +
    statefulset.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '3000',
      }) +
      pod.container(
        container.new(app, image) +
        container.port('http', 3000) +
        container.volume('config', '/etc/grafana') +
        container.volume('data', '/var/lib/grafana') +
        container.resources('50m', '50m', '64Mi', '64Mi') +
        container.http_probe('readiness', '/api/health') +
        container.http_probe('liveness', '/api/health')
      ) +
      pod.volume_configmap('config', configmap=app, items={
        'grafana.ini': 'grafana.ini',
        'datasources.yaml': 'provisioning/datasources/datasources.yaml',
        'dashboards.yaml': 'provisioning/dashboards/dashboards.yaml',
        'container-overview.json': 'dashboards/container-overview.json',
        'pod-overview.json': 'dashboards/pod-overview.json',
        'resource-overview.json': 'dashboards/resource-overview.json',
      }) +
      pod.security_context({ runAsUser: 472, runAsGroup: 472 })
    ) +
    statefulset.volume_claim('data', '10Gi'),
  ]
