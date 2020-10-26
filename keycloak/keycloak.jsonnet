local certificate = import '../templates/certificate.jsonnet';
local configmap = import '../templates/configmap.jsonnet';
local container = import '../templates/container.jsonnet';
local deployment = import '../templates/deployment.jsonnet';
local destinationrule = import '../templates/destinationrule.jsonnet';
local gateway = import '../templates/gateway.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local secret = import '../templates/secret.jsonnet';
//local peerauthentication = import '../templates/peerauthentication.jsonnet';
local openidprovider = import '../templates/openidprovider.jsonnet';
local pod = import '../templates/pod.jsonnet';
local role = import '../templates/role.jsonnet';
local rolebinding = import '../templates/rolebinding.jsonnet';
local service = import '../templates/service.jsonnet';
local serviceaccount = import '../templates/serviceaccount.jsonnet';
local virtualservice = import '../templates/virtualservice.jsonnet';

local app = 'keycloak';
local image = 'jboss/keycloak:9.0.0';

function(config)
  local ns = config.keycloak.namespace;
  local keycloak = config.keycloak;

  [
    serviceaccount.new() +
    metadata.new(app, ns=ns),

    role.new(cluster=true) +
    metadata.new('%s-%s' % [app, ns]) +
    role.rule({
      apiGroups: [''],
      verbs: ['get', 'list'],
      resources: ['pods'],
    }),

    rolebinding.new(cluster=true) +
    metadata.new('%s-%s' % [app, ns]) +
    rolebinding.role('%s-%s' % [app, ns], cluster=true) +
    rolebinding.subject('ServiceAccount', app, ns=ns),
  ] +
  (if keycloak.tls.acme then [certificate.new(keycloak.externalAddress)] else []) +
  [
    gateway.new(keycloak.externalAddress, tls=keycloak.tls.enabled) +
    metadata.new(app, ns=ns),

    virtualservice.new() +
    metadata.new(app, ns=ns) +
    virtualservice.host(keycloak.externalAddress) +
    virtualservice.gateway(app) +
    virtualservice.route(app),

    destinationrule.new(app) +
    metadata.new(app, ns=ns) +
    destinationrule.circuitBreaker(),

    service.new(app) +
    metadata.new(app, ns=ns) +
    service.port(8080),

    destinationrule.new(app + '-gossip') +
    metadata.new(app + '-gossip', ns=ns) +
    destinationrule.mtls(false) +
    destinationrule.circuitBreaker(),

    service.new(app, headless=true) +
    metadata.new(app + '-gossip', ns=ns) +
    service.port(7600, name='tcp-gossip'),

    // TODO: Why doesn't it work when adding this and removing the excludeInboundPorts?
    //peerauthentication.new({ app: app }) +
    //metadata.new(app, ns=ns) +
    //peerauthentication.mtls(true) +
    //peerauthentication.mtls(false, 7600),

    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data((import 'keycloak.env.jsonnet')(app, config).configmap),

    secret.new() +
    metadata.new(app, ns=ns) +
    secret.data((import 'keycloak.env.jsonnet')(app, config).secret),

    deployment.new(replicas=keycloak.replicas) +
    metadata.new(app, ns=ns) +
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
        container.envFrom(configmap=app) +
        container.envFrom(secret=app) +
        container.port('http', 8080) +
        container.port('tcp-gossip', 7600) +
        container.resources('100m', '1500m', '768Mi', '768Mi') +
        container.httpProbe('readiness', '/auth/realms/master') +
        container.httpProbe('liveness', '/', delay=120)
        // TODO: container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.serviceAccount(app) +
      pod.securityContext({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.affinity(keycloak.affinity) +
      pod.tolerations(keycloak.tolerations)
    ),

    openidprovider.new('http://keycloak:8080/auth/realms/master') +
    metadata.new(app, ns=ns) +
    openidprovider.roleMapping('realm_access.roles'),
  ]
