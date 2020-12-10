local certificate = import '../templates/certificate.jsonnet';
local configmap = import '../templates/configmap.jsonnet';
local container = import '../templates/container.jsonnet';
local deployment = import '../templates/deployment.jsonnet';
local destinationrule = import '../templates/destinationrule.jsonnet';
local gateway = import '../templates/gateway.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local pod = import '../templates/pod.jsonnet';
local role = import '../templates/role.jsonnet';
local rolebinding = import '../templates/rolebinding.jsonnet';
local secret = import '../templates/secret.jsonnet';
local service = import '../templates/service.jsonnet';
local serviceaccount = import '../templates/serviceaccount.jsonnet';
local virtualservice = import '../templates/virtualservice.jsonnet';
local kialiYaml = import 'kiali.yaml.jsonnet';

local app = 'kiali';
local version = 'v1.27.0';
local image = 'quay.io/kiali/kiali:' + version;

function(global, kiali, keycloak, grafana, jaeger)
  [
    destinationrule.new('istiod.istio-system.svc.cluster.local') +
    metadata.new('istiod.istio-system', global.namespace) +
    destinationrule.mtls(false),

    serviceaccount.new() +
    metadata.new(app, global.namespace),

    role.new(cluster=true) +
    metadata.new(app + '-' + global.namespace) +
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
    metadata.new(app + '-' + global.namespace) +
    rolebinding.role(app + '-' + global.namespace, cluster=true) +
    rolebinding.subject('ServiceAccount', app, global.namespace),
  ] +
  (if global.tls then [certificate.new(kiali.externalAddress)] else []) +
  [
    gateway.new(kiali.externalAddress, tls=global.tls) +
    metadata.new(app, global.namespace),

    virtualservice.new() +
    metadata.new(app, global.namespace) +
    virtualservice.host(kiali.externalAddress) +
    virtualservice.gateway(app) +
    virtualservice.route(app, port=20001),

    destinationrule.new(app) +
    metadata.new(app, global.namespace) +
    destinationrule.circuitBreaker(),

    service.new(app) +
    metadata.new(app, global.namespace) +
    service.port(20001) +
    service.port(9090, name='http-telemetry'),

    configmap.new() +
    metadata.new(app, global.namespace) +
    configmap.data({
      'config.yaml': std.manifestYamlDoc(kialiYaml(global, kiali, keycloak, grafana, jaeger)),
    }),

    secret.new() +
    metadata.new(app, global.namespace) +
    secret.data({ LOGIN_TOKEN_SIGNING_KEY: kiali.oidc.signingKey }),

    deployment.new(version=version, replicas=kiali.replicas) +
    metadata.new(app, global.namespace) +
    deployment.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '9090',
      }) +
      pod.container(
        container.new(app, image) +
        container.args(['-config', '/etc/kiali/config.yaml']) +
        container.env({
          LOGIN_TOKEN_SIGNING_KEY:
            { secretKeyRef: { name: app, key: 'LOGIN_TOKEN_SIGNING_KEY' } },
        }) +
        container.port('http', 20001) +
        container.port('http-telemetry', 9090) +
        container.volume('config', '/etc/kiali') +
        container.resources('50m', '500m', '128Mi', '128Mi') +
        container.httpProbe('readiness', '/healthz', port='http') +
        container.httpProbe('liveness', '/healthz', port='http') +
        {}  //container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.serviceAccount(app) +
      pod.volumeConfigMap('config', configmap=app) +
      pod.securityContext({ runAsUser: 1000, runAsGroup: 1000 }) +
      pod.affinity(global.affinity) +
      pod.tolerations(global.tolerations)
    ),
  ]
