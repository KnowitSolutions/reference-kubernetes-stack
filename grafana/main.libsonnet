local authorizationpolicy = import '../templates/authorizationpolicy.libsonnet';
local certificate = import '../templates/certificate.libsonnet';
local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
local deployment = import '../templates/deployment.libsonnet';
local destinationrule = import '../templates/destinationrule.libsonnet';
local gateway = import '../templates/gateway.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local pod = import '../templates/pod.libsonnet';
local secret = import '../templates/secret.libsonnet';
local service = import '../templates/service.libsonnet';
local statefulset = import '../templates/statefulset.libsonnet';
local virtualservice = import '../templates/virtualservice.libsonnet';

local app = 'grafana';
local image = 'grafana/grafana:6.6.1';

function(config)
  local ns = config.grafana.namespace;
  local grafana = config.grafana;
  local keycloak = config.keycloak;
  local postgres = grafana.postgres;

  [
    destinationrule.new('prometheus.istio-system.svc.cluster.local') +
    metadata.new('prometheus.istio-system', ns=ns) +
    destinationrule.mtls(false),
  ] +
  (if grafana.tls.acme then [certificate.new(grafana.external_address)] else []) +
  [
    gateway.new(grafana.external_address, tls=grafana.tls.enabled) +
    metadata.new(app, ns=ns),

    virtualservice.new() +
    metadata.new(app, ns=ns) +
    virtualservice.host(grafana.external_address) +
    virtualservice.gateway(app) +
    virtualservice.route(app),

    authorizationpolicy.new({ app: app }) +
    metadata.new(app, ns=ns) +
    authorizationpolicy.rule(
      authorizationpolicy.from({ principals: ['*/ns/istio-system/sa/istio-ingressgateway-service-account'] }) +
      authorizationpolicy.to({ paths: ['/metrics'] })
    ) +
    authorizationpolicy.allow(false),

    destinationrule.new(app) +
    metadata.new(app, ns=ns) +
    destinationrule.circuit_breaker(),

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

    secret.new() +
    metadata.new(app, ns=ns) +
    secret.data({
      [if postgres.enabled then 'GF_DATABASE_USER']: postgres.username,
      [if postgres.enabled then 'GF_DATABASE_PASSWORD']: postgres.password,
      GF_AUTH_GENERIC_OAUTH_CLIENT_ID: grafana.oidc.client_id,
      GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET: grafana.oidc.client_secret,
    }),

    (if postgres.enabled then deployment else statefulset).new(replicas=grafana.replicas) +
    metadata.new(app, ns=ns) +
    (if postgres.enabled then deployment else statefulset).pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '3000',
      }) +
      pod.container(
        container.new(app, image) +
        container.port('http', 3000) +
        container.env_from(secret=app) +
        container.volume('config', '/etc/grafana') +
        container.volume('data', '/var/lib/grafana') +
        container.resources('50m', '50m', '64Mi', '64Mi') +
        container.http_probe('readiness', '/api/health') +
        container.http_probe('liveness', '/api/health') +
        container.security_context({ readOnlyRootFilesystem: true })
      ) +
      pod.volume_configmap('config', configmap=app, items={
        'grafana.ini': 'grafana.ini',
        'datasources.yaml': 'provisioning/datasources/datasources.yaml',
        'dashboards.yaml': 'provisioning/dashboards/dashboards.yaml',
        'container-overview.json': 'dashboards/container-overview.json',
        'pod-overview.json': 'dashboards/pod-overview.json',
        'resource-overview.json': 'dashboards/resource-overview.json',
      }) +
      (if postgres.enabled then pod.volume_emptydir('data', '1Mi') else {}) +
      pod.security_context({ runAsUser: 472, runAsGroup: 472 }) +
      pod.node_selector(grafana.node_selector) +
      pod.tolerations(grafana.node_tolerations)
    ) +
    (if !postgres.enabled then statefulset.volume_claim('data', '50Mi') else {}),
  ]
