local kubernetesMixin = import '../kubernetes-mixin/mixin.jsonnet';
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
local version = '9.2.0';
local image = 'grafana/grafana:' + version;

local reduce = function(arr) std.foldl(function(a, b) a + b, arr, {});

function(global, grafana, sql, keycloak)
  (if global.tls then [certificate.new(grafana.externalAddress)] else []) +
  [
    gateway.new(grafana.externalAddress, tls=global.tls) +
    metadata.new(app, global.namespace),

    virtualservice.new() +
    metadata.new(app, global.namespace) +
    virtualservice.host(grafana.externalAddress) +
    virtualservice.gateway(app) +
    virtualservice.route(app),

    authorizationpolicy.new({ app: app }) +
    metadata.new(app, global.namespace) +
    authorizationpolicy.rule(
      authorizationpolicy.from({ principals: ['*/ns/istio-system/sa/istio-ingressgateway-service-account'] }) +
      authorizationpolicy.to({ paths: ['/metrics'] })
    ) +
    authorizationpolicy.allow(false),

    destinationrule.new(app) +
    metadata.new(app, global.namespace) +
    destinationrule.circuitBreaker(),

    service.new(app) +
    metadata.new(app, global.namespace) +
    service.port(3000),

    configmap.new() +
    metadata.new(app, global.namespace) +
    configmap.data({
      'grafana.ini': std.manifestIni((import 'grafana.ini.jsonnet')(global, grafana, sql, keycloak)),
      'datasources.yaml': importstr 'datasources.yaml',
      'dashboards.yaml': importstr 'dashboards.yaml',
    }),

  ] + [
    local name = std.substr(key, 0, std.length(key) - 5);
    local value = kubernetesMixin.grafanaDashboards[key];
    configmap.new() +
    metadata.new(app + '-dashboard-' + name, global.namespace) +
    configmap.data({ [key]: std.manifestJson(value) })
    for key in if grafana.dashboards then std.objectFields(kubernetesMixin.grafanaDashboards) else []
  ] + [

    secret.new() +
    metadata.new(app, global.namespace) +
    secret.data({
      [if sql.vendor == 'postgres' then 'GF_DATABASE_USER']: sql.username,
      [if sql.vendor == 'postgres' then 'GF_DATABASE_PASSWORD']: sql.password,
      GF_AUTH_GENERIC_OAUTH_CLIENT_ID: grafana.oidc.clientId,
      GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET: grafana.oidc.clientSecret,
    }),

    (if sql.vendor == 'postgres' then deployment else statefulset).new(version=version, replicas=grafana.replicas) +
    metadata.new(app, global.namespace) +
    (if sql.vendor == 'postgres' then deployment else statefulset).pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '3000',
      }) +
      pod.container(
        container.new(app, image) +
        container.port('http', 3000) +
        container.env({
          [if sql.vendor == 'postgres' then 'GF_DATABASE_USER']:
            { secretKeyRef: { name: app, key: 'GF_DATABASE_USER' } },
          [if sql.vendor == 'postgres' then 'GF_DATABASE_PASSWORD']:
            { secretKeyRef: { name: app, key: 'GF_DATABASE_PASSWORD' } },
          GF_AUTH_GENERIC_OAUTH_CLIENT_ID:
            { secretKeyRef: { name: app, key: 'GF_AUTH_GENERIC_OAUTH_CLIENT_ID' } },
          GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET:
            { secretKeyRef: { name: app, key: 'GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET' } },
        }) +
        container.volume('config', '/etc/grafana') +
        container.volume('dashboards', '/etc/grafana/dashboards') +
        reduce([
          local name = std.substr(key, 0, std.length(key) - 5);
          container.volume('dashboard-' + name, '/etc/grafana/dashboards/' + key, subPath=key)
          for key in std.objectFields(kubernetesMixin.grafanaDashboards)
        ]) +
        container.volume('data', '/var/lib/grafana') +
        container.resources('50m', '200m', '64Mi', '64Mi') +
        container.httpProbe('readiness', '/api/health') +
        container.httpProbe('liveness', '/api/health') +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.volumeConfigMap('config', configmap=app, items={
        'grafana.ini': 'grafana.ini',
        'datasources.yaml': 'provisioning/datasources/datasources.yaml',
        'dashboards.yaml': 'provisioning/dashboards/dashboards.yaml',
      }) +
      pod.volumeEmptyDir('dashboards', '0') +
      reduce([
        local name = std.substr(key, 0, std.length(key) - 5);
        pod.volumeConfigMap('dashboard-' + name, configmap=app + '-dashboard-' + name, optional=true)
        for key in std.objectFields(kubernetesMixin.grafanaDashboards)
      ]) +
      (if sql.vendor == 'postgres' then pod.volumeEmptyDir('data', '1Mi') else {}) +
      pod.securityContext({ runAsUser: 472, runAsGroup: 472 }) +
      pod.affinity(global.affinity) +
      pod.tolerations(global.tolerations)
    ) +
    (if sql.vendor != 'postgres' then statefulset.volumeClaim('data', '50Mi') else {}),
  ]
