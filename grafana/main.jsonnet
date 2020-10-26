local authorizationpolicy = import '../templates/authorizationpolicy.jsonnet';
local certificate = import '../templates/certificate.jsonnet';
local configmap = import '../templates/configmap.jsonnet';
local container = import '../templates/container.jsonnet';
local deployment = import '../templates/deployment.jsonnet';
local destinationrule = import '../templates/destinationrule.jsonnet';
local gateway = import '../templates/gateway.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local pod = import '../templates/pod.jsonnet';
local secret = import '../templates/secret.jsonnet';
local service = import '../templates/service.jsonnet';
local statefulset = import '../templates/statefulset.jsonnet';
local virtualservice = import '../templates/virtualservice.jsonnet';

local app = 'grafana';
local image = 'grafana/grafana:7.1.5';

// TODO: Switch to Istio OIDC
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
  (if grafana.tls.acme then [certificate.new(grafana.externalAddress)] else []) +
  [
    gateway.new(grafana.externalAddress, tls=grafana.tls.enabled) +
    metadata.new(app, ns=ns),

    virtualservice.new() +
    metadata.new(app, ns=ns) +
    virtualservice.host(grafana.externalAddress) +
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
    destinationrule.circuitBreaker(),

    service.new(app) +
    metadata.new(app, ns=ns) +
    service.port(3000),

    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'grafana.ini': std.manifestIni((import 'grafana.ini.jsonnet')(config)),
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
      GF_AUTH_GENERIC_OAUTH_CLIENT_ID: grafana.oidc.clientId,
      GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET: grafana.oidc.clientSecret,
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
        container.envFrom(secret=app) +
        container.volume('config', '/etc/grafana') +
        container.volume('data', '/var/lib/grafana') +
        container.resources('50m', '50m', '64Mi', '64Mi') +
        container.httpProbe('readiness', '/api/health') +
        container.httpProbe('liveness', '/api/health') +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.volumeConfigMap('config', configmap=app, items={
        'grafana.ini': 'grafana.ini',
        'datasources.yaml': 'provisioning/datasources/datasources.yaml',
        'dashboards.yaml': 'provisioning/dashboards/dashboards.yaml',
        'container-overview.json': 'dashboards/container-overview.json',
        'pod-overview.json': 'dashboards/pod-overview.json',
        'resource-overview.json': 'dashboards/resource-overview.json',
      }) +
      (if postgres.enabled then pod.volumeEmptyDir('data', '1Mi') else {}) +
      pod.securityContext({ runAsUser: 472, runAsGroup: 472 }) +
      pod.affinity(grafana.affinity) +
      pod.tolerations(grafana.tolerations)
    ) +
    (if !postgres.enabled then statefulset.volumeClaim('data', '50Mi') else {}),
  ]
