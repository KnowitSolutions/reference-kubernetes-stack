local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
local deployment = import '../templates/deployment.libsonnet';
local gateway = import '../templates/gateway.libsonnet';
local job = import '../templates/job.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
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

    deployment.new(replicas=2) +
    metadata.new(app, ns=ns) +
    deployment.pod(
      pod.new() +
      metadata.new(app) +
      pod.container(
        container.new(app, image) +
        container.env({  // TODO: Check these settings
          KEYCLOAK_USER: 'admin',
          KEYCLOAK_PASSWORD: 'admin',
          DB_VENDOR: 'postgres',  // TODO: Configurable as TLAs
          DB_ADDR: 'postgres.db',
          DB_DATABASE: 'postgres',
          DB_USER: 'postgres',
          DB_PASSWORD: 'postgres',
          JGROUPS_DISCOVERY_PROTOCOL: 'kubernetes.KUBE_PING',
          JGROUPS_DISCOVERY_PROPERTIES: 'namespace=' + ns,
          KEYCLOAK_FRONTEND_URL: 'http://%s/auth' % [keycloak.external_address],
          PROXY_ADDRESS_FORWARDING: 'true',
          KEYCLOAK_STATISTICS: 'all',
        }) +
        container.port('http', 8080) +
        container.http_probe('readiness', '/auth/realms/master') +
        container.http_probe('liveness', '/', delay=90)
      ) +
      pod.service_account(app) +
      pod.security_context({ runAsNonRoot: true }),
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
        container.volume('script', '/initialize.sh', sub_path='initialize.sh')
      ) +
      pod.security_context({ runAsNonRoot: true }) +
      pod.volume_configmap('script', init, default_mode=std.parseOctal('555'))
    ),
  ]
