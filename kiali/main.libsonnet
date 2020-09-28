local accesspolicy = import '../templates/accesspolicy.libsonnet';
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
    virtualservice.route(app, port=20001),

    accesspolicy.new(app) +
    metadata.new(app, ns=ns) +
    accesspolicy.credentials(app),

    secret.new() +
    metadata.new(app, ns=ns) +
    secret.data({
      clientID: kiali.oidc.client_id,
      clientSecret: kiali.oidc.client_secret,
    }),

    destinationrule.new(app) +
    metadata.new(app, ns=ns) +
    destinationrule.circuit_breaker(),

    service.new(app) +
    metadata.new(app, ns=ns) +
    service.port(20001) +
    service.port(9090, name='http-telemetry'),

    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'config.yaml': std.manifestYamlDoc((import 'kiali.yaml.libsonnet')(config)),
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
        container.port('http', 20001) +
        container.port('http-telemetry', 9090) +
        container.volume('config', '/etc/kiali') +
        container.resources('200m', '200m', '64Mi', '64Mi') +
        container.http_probe('readiness', '/healthz', port='http') +
        container.http_probe('liveness', '/healthz', port='http') +
        container.security_context({ readOnlyRootFilesystem: true })
      ) +
      pod.service_account(app) +
      pod.volume_configmap('config', configmap=app) +
      pod.security_context({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.affinity(kiali.affinity) +
      pod.tolerations(kiali.tolerations)
    ),
  ]
