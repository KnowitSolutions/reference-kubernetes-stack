local configmap = import '../templates/configmap.jsonnet';
local container = import '../templates/container.jsonnet';
local destinationrule = import '../templates/destinationrule.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local pod = import '../templates/pod.jsonnet';
local role = import '../templates/role.jsonnet';
local rolebinding = import '../templates/rolebinding.jsonnet';
local service = import '../templates/service.jsonnet';
local serviceaccount = import '../templates/serviceaccount.jsonnet';
local statefulset = import '../templates/statefulset.jsonnet';

local app = 'prometheus';
local image = 'prom/prometheus:v2.22.0';

function(config)
  local ns = config.prometheus.namespace;
  local prometheus = config.prometheus;

  [
    serviceaccount.new() +
    metadata.new(app, ns=ns),

    role.new(cluster=true) +
    metadata.new('%s-%s' % [app, ns]) +
    role.rule({
      apiGroups: [''],
      verbs: ['get', 'list', 'watch'],
      resources: [
        'nodes',
        'nodes/proxy',
        'nodes/metrics',
        'services',
        'endpoints',
        'pods',
        'ingresses',
        'configmaps',
      ],
    }) +
    role.rule({
      apiGroups: ['networking.k8s.io'],
      verbs: ['get', 'list', 'watch'],
      resources: ['ingresses', 'ingresses/status'],
    }) +
    role.rule({
      verbs: ['get'],
      nonResourceURLs: ['/metrics'],
    }),

    rolebinding.new(cluster=true) +
    metadata.new('%s-%s' % [app, ns]) +
    rolebinding.role('%s-%s' % [app, ns], cluster=true) +
    rolebinding.subject('ServiceAccount', app, ns=ns),

    destinationrule.new(app) +
    metadata.new(app, ns=ns) +
    destinationrule.circuitBreaker() +
    destinationrule.stickySessions(),

    service.new(app) +
    metadata.new(app, ns=ns) +
    service.port(9090, name='http'),

    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'prometheus.yaml': importstr 'prometheus.yaml',
    }),

    statefulset.new(replicas=prometheus.replicas, parallel=true, service=app) +
    metadata.new(app, ns=ns) +
    statefulset.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '9090',
      }) +
      pod.container(
        container.new(app, image) +
        container.args([
          '--config.file=/etc/prometheus/prometheus.yaml',
          '--storage.tsdb.retention.time=30d',
        ]) +
        container.port('http', 9090) +
        container.volume('config', '/etc/prometheus', readOnly=true) +
        container.volume('data', '/prometheus/data') +
        container.resources('100m', '100m', '3Gi', '3Gi') +
        container.httpProbe('readiness', '/-/ready', port='http') +
        container.httpProbe('liveness', '/-/healthy', port='http') +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.serviceAccount(app) +
      pod.volumeConfigMap('config', configmap=app) +
      pod.securityContext({ runAsUser: 65534, runAsGroup: 65534 }) +
      pod.affinity(prometheus.affinity) +
      pod.tolerations(prometheus.tolerations)
    ) +
    statefulset.volumeClaim('data', '5Gi'),
  ]
