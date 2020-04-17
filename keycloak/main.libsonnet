local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
local deployment = import '../templates/deployment.libsonnet';
local destinationrule = import '../templates/destinationrule.libsonnet';
local gateway = import '../templates/gateway.libsonnet';
local job = import '../templates/job.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
//local peerauthentication = import '../templates/peerauthentication.libsonnet';
local pod = import '../templates/pod.libsonnet';
local role = import '../templates/role.libsonnet';
local rolebinding = import '../templates/rolebinding.libsonnet';
local service = import '../templates/service.libsonnet';
local serviceaccount = import '../templates/serviceaccount.libsonnet';
local virtualservice = import '../templates/virtualservice.libsonnet';

local app = 'keycloak';
local init = app + '-initialize';
local image = 'jboss/keycloak:9.0.0';

function(config)
  local ns = config.keycloak.namespace;
  local keycloak = config.keycloak;
  local postgres = keycloak.postgres;

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

    gateway.new(keycloak.external_address) +
    metadata.new(app, ns=ns),

    virtualservice.new() +
    metadata.new(app, ns=ns) +
    virtualservice.host(keycloak.external_address) +
    virtualservice.gateway(app) +
    virtualservice.route(app),

    service.new(app) +
    metadata.new(app, ns=ns) +
    service.port(8080),

    destinationrule.new(app + '-gossip') +
    metadata.new(app + '-gossip', ns=ns) +
    destinationrule.mtls(false),

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
    configmap.data((import 'keycloak.env.libsonnet')(app, config)),

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
        container.env_from(configmap=app) +
        container.port('http', 8080) +
        container.port('tcp-gossip', 7600) +
        container.resources('100m', '1500m', '512Mi', '512Mi') +
        container.http_probe('readiness', '/auth/realms/master') +
        container.http_probe('liveness', '/', delay=120)
      ) +
      pod.service_account(app) +
      pod.security_context({ runAsUser: 1000, runAsGroup: 1000 }),
    ),

    configmap.new() +
    metadata.new(init, ns=ns) +
    configmap.data({
      'initialize.sh': (import 'initialize.sh.libsonnet')(config),
    }),

    job.new() +
    metadata.new(init, ns=ns) +
    job.pod(
      pod.new() +
      metadata.new(init) +
      pod.container(
        container.new(init, image) +
        container.command(['/initialize.sh']) +
        container.volume('script', '/initialize.sh', sub_path='initialize.sh') +
        container.resources('1000m', '1000m', '256Mi', '256Mi')
      ) +
      pod.security_context({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.volume_configmap('script', init, default_mode=std.parseOctal('555'))
    ),
  ]
