local certificate = import '../templates/certificate.jsonnet';
local configmap = import '../templates/configmap.jsonnet';
local container = import '../templates/container.jsonnet';
local deployment = import '../templates/deployment.jsonnet';
local destinationrule = import '../templates/destinationrule.jsonnet';
local gateway = import '../templates/gateway.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local secret = import '../templates/secret.jsonnet';
//local peerauthentication = import '../templates/peerauthentication.jsonnet';
local pod = import '../templates/pod.jsonnet';
local role = import '../templates/role.jsonnet';
local rolebinding = import '../templates/rolebinding.jsonnet';
local service = import '../templates/service.jsonnet';
local serviceaccount = import '../templates/serviceaccount.jsonnet';
local virtualservice = import '../templates/virtualservice.jsonnet';

local app = 'keycloak';
local version = '9.0.0';
local image = 'jboss/keycloak:' + version;

function(global, keycloak, sql, grafana, kiali, jaeger)
  local config = (import 'config.jsonnet')(global, keycloak, sql, grafana, kiali, jaeger);
  [
    serviceaccount.new() +
    metadata.new(app, global.namespace),

    role.new(cluster=true) +
    metadata.new(app + '-' + global.namespace) +
    role.rule({
      apiGroups: [''],
      verbs: ['get', 'list'],
      resources: ['pods'],
    }),

    rolebinding.new(cluster=true) +
    metadata.new(app + '-' + global.namespace) +
    rolebinding.role(app + '-' + global.namespace, cluster=true) +
    rolebinding.subject('ServiceAccount', app, global.namespace),
  ] +
  (if global.tls then [certificate.new(keycloak.externalAddress)] else []) +
  [
    gateway.new(keycloak.externalAddress, tls=global.tls) +
    metadata.new(app, global.namespace),

    virtualservice.new() +
    metadata.new(app, global.namespace) +
    virtualservice.host(keycloak.externalAddress) +
    virtualservice.gateway(app) +
    virtualservice.route(app),

    destinationrule.new(app) +
    metadata.new(app, global.namespace) +
    destinationrule.circuitBreaker(),

    service.new(app) +
    metadata.new(app, global.namespace) +
    service.port(8080),

    destinationrule.new(app + '-headless') +
    metadata.new(app + '-headless', global.namespace) +
    destinationrule.mtls(false) +
    destinationrule.circuitBreaker(),

    service.new(app, headless=true) +
    metadata.new(app + '-headless', global.namespace) +
    service.port(7600, name='tcp-jgroups'),

    // TODO: Why doesn't it work when adding this and removing the excludeInboundPorts?
    //peerauthentication.new({ app: app }) +
    //metadata.new(app, global.namespace) +
    //peerauthentication.mtls(true) +
    //peerauthentication.mtls(false, 7600),

    configmap.new() +
    metadata.new(app, global.namespace) +
    configmap.data({
      'environment.sh': config.configmap,
      'entrypoint.sh': config.entrypoint,
    }),

    secret.new() +
    metadata.new(app, global.namespace) +
    secret.data({
      'environment.sh': config.secret,
    }),

    deployment.new(version=version, replicas=keycloak.replicas) +
    metadata.new(app, global.namespace) +
    deployment.pod(
      pod.new() +
      metadata.new(app) +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '9990',
        'traffic.sidecar.istio.io/excludeInboundPorts': '7600',
      }) +
      pod.container(
        container.new(app, image) +
        container.command(['/tmp/configmap/entrypoint.sh']) +
        container.port('http', 8080) +
        container.port('tcp-jgroups', 7600) +
        container.volume('configmap', '/tmp/configmap') +
        container.volume('secret', '/tmp/secret') +
        container.resources('50m', '1500m', '768Mi', '768Mi') +
        container.httpProbe('readiness', '/auth/realms/master') +
        container.httpProbe('liveness', '/', delay=120)
        // TODO: container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.volumeConfigMap('configmap', app, defaultMode=std.parseOctal('555')) +
      pod.volumeSecret('secret', app, defaultMode=std.parseOctal('555')) +
      pod.serviceAccount(app) +
      pod.securityContext({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.affinity(global.affinity) +
      pod.tolerations(global.tolerations)
    ),
  ]
