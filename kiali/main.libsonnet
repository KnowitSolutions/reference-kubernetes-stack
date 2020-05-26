local certificate = import '../templates/certificate.libsonnet';
local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
local deployment = import '../templates/deployment.libsonnet';
local destinationrule = import '../templates/destinationrule.libsonnet';
local gateway = import '../templates/gateway.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local pod = import '../templates/pod.libsonnet';
local role = import '../templates/role.libsonnet';
local rolebinding = import '../templates/rolebinding.libsonnet';
local secret = import '../templates/secret.libsonnet';
local service = import '../templates/service.libsonnet';
local serviceaccount = import '../templates/serviceaccount.libsonnet';
local virtualservice = import '../templates/virtualservice.libsonnet';

local app = 'kiali';
local image = 'quay.io/kiali/kiali:v1.18.1';
local auth_app = 'oauth2-proxy';
local auth_image = 'quay.io/oauth2-proxy/oauth2-proxy:v5.1.0';

function(config)
  local ns = config.kiali.namespace;
  local kiali = config.kiali;
  local keycloak = config.keycloak;

  [
    destinationrule.new('istiod.istio-system.svc.cluster.local') +
    metadata.new('istiod.istio-system', ns=ns) +
    destinationrule.mtls(false),

    destinationrule.new('prometheus.istio-system.svc.cluster.local') +
    metadata.new('prometheus.istio-system', ns=ns) +
    destinationrule.mtls(false),

    serviceaccount.new() +
    metadata.new(app, ns=ns),

    role.new(cluster=true) +
    metadata.new('%s-%s' % [app, ns]) +
    role.rule({
      apiGroups: [''],
      verbs: ['get', 'list', 'watch'],
      resources: [
        'configmaps',
        'endpoints',
        'namespaces',
        'nodes',
        'pods',
        'pods/log',
        'replicationcontrollers',
        'services',
      ],
    }) +
    role.rule({
      apiGroups: ['autoscaling'],
      verbs: ['get', 'list', 'watch'],
      resources: ['horizontalpodautoscalers'],
    }) +
    role.rule({
      apiGroups: ['apps', 'extensions'],
      verbs: ['get', 'list', 'watch'],
      resources: [
        'deployments',
        'replicasets',
        'statefulsets',
      ],
    }) +
    role.rule({
      apiGroups: ['batch'],
      verbs: ['get', 'list', 'watch'],
      resources: ['cronjobs', 'jobs'],
    }) +
    role.rule({
      apiGroups: [
        'config.istio.io',
        'networking.istio.io',
        'authentication.istio.io',
        'rbac.istio.io',
        'security.istio.io',
      ],
      verbs: ['get', 'list', 'watch'],
      resources: ['*'],
    }) +
    role.rule({
      apiGroups: ['monitoring.kiali.io'],
      verbs: ['get', 'list'],
      resources: ['monitoringdashboards'],
    }),

    rolebinding.new(cluster=true) +
    metadata.new('%s-%s' % [app, ns]) +
    rolebinding.role('%s-%s' % [app, ns], cluster=true) +
    rolebinding.subject('ServiceAccount', app, ns=ns),
  ] +
  (if kiali.tls.acme then [certificate.new(kiali.external_address)] else []) +
  [
    gateway.new(kiali.external_address, tls=kiali.tls.enabled) +
    metadata.new(app, ns=ns),

    virtualservice.new() +
    metadata.new(app, ns=ns) +
    virtualservice.host(kiali.external_address) +
    virtualservice.gateway(app) +
    virtualservice.route(app, port=4180),

    destinationrule.new(app) +
    metadata.new(app, ns=ns) +
    destinationrule.circuit_breaker(),

    service.new(app) +
    metadata.new(app, ns=ns) +
    service.port(4180) +
    service.port(9090, name='http-telemetry'),

    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'config.yaml': std.manifestYamlDoc((import 'kiali.yaml.libsonnet')(config)),
    }),

    secret.new() +
    metadata.new(app, ns=ns) +
    secret.data({
      OIDC_CLIENT_ID: kiali.oidc.client_id,
      OIDC_CLIENT_SECRET: kiali.oidc.client_secret,
    }),

    deployment.new(replicas=kiali.replicas) +
    metadata.new(app, ns=ns) +
    deployment.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '9090',
      }) +
      pod.container(
        container.new(app, image) +
        container.args(['-config', '/etc/kiali/config.yaml']) +
        container.port('http-direct', 20001) +
        container.port('http-telemetry', 9090) +
        container.volume('config', '/etc/kiali') +
        container.resources('200m', '200m', '64Mi', '64Mi') +
        container.http_probe('readiness', '/healthz', port='http-direct') +
        container.http_probe('liveness', '/healthz', port='http-direct') +
        container.security_context({ readOnlyRootFilesystem: true })
      ) +
      pod.container(
        container.new(auth_app, auth_image) +
        container.args([
          '--upstream=http://127.0.0.1:20001',
          '--skip-provider-button',
          '--provider=oidc',
          '--skip-oidc-discovery=true',
          '--oidc-issuer-url=%s://%s/auth/realms/master' % [keycloak.external_protocol, keycloak.external_address],
          '--login-url=%s://%s/auth/realms/master/protocol/openid-connect/auth' % [keycloak.external_protocol, keycloak.external_address],
          '--redeem-url=http://%s:8080/auth/realms/master/protocol/openid-connect/token' % keycloak.internal_address,
          '--oidc-jwks-url=http://%s:8080/auth/realms/master/protocol/openid-connect/certs' % keycloak.internal_address,
          '--client-id=%s' % kiali.oidc.client_id,
          '--client-secret=%s' % kiali.oidc.client_secret,
          '--redirect-url=%s://%s/oauth2/callback' % [kiali.external_protocol, kiali.external_address],
          '--cookie-secret=secret',  // TODO: Change
          '--cookie-secure=false',
          '--email-domain=*',
        ]) +
        container.port('http', 4180) +
        // TODO: resources
        container.http_probe('readiness', '/ping') +
        container.http_probe('liveness', '/ping')
      ) +
      pod.service_account(app) +
      pod.volume_configmap('config', configmap=app) +
      pod.security_context({ runAsUser: 1000, runAsGroup: 1000 })
    ),
  ]
