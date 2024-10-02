local kubernetesMixin = import '../kubernetes-mixin/mixin.jsonnet';
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
local version = 'v2.22.0';
local image = 'prom/prometheus:' + version;

function(global, prometheus)
  [
    serviceaccount.new() +
    metadata.new(app, global.namespace),

    role.new(cluster=true) +
    metadata.new(app + '-' + global.namespace) +
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
    metadata.new(app + '-' + global.namespace) +
    rolebinding.role(app + '-' + global.namespace, cluster=true) +
    rolebinding.subject('ServiceAccount', app, global.namespace),

    destinationrule.new(app) +
    metadata.new(app, global.namespace) +
    destinationrule.circuitBreaker() +
    destinationrule.stickySessions(),

    service.new(app) +
    metadata.new(app, global.namespace) +
    service.port(9090, name='http'),

    configmap.new() +
    metadata.new(app, global.namespace) +
    configmap.data({
      'prometheus.yaml': importstr 'prometheus.yaml',
      'alerts.yaml': std.manifestYamlDoc(kubernetesMixin.prometheusAlerts),
      'rules.yaml': std.manifestYamlDoc(kubernetesMixin.prometheusRules),
    }),

    statefulset.new(version=version, replicas=prometheus.replicas, parallel=true, service=app) +
    metadata.new(app, global.namespace) +
    statefulset.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '9090',
      }) +
      pod.container(
        container.new(app, image) +
        container.args([
          '--config.file=/prometheus/config/prometheus.yaml',
          '--storage.tsdb.retention.time=30d',
        ]) +
        container.port('http', 9090) +
        container.volume('config', '/prometheus/config', readOnly=true) +
        container.volume('data', '/prometheus/data') +
        container.resources('1', '2', '8Gi', '12Gi') +
        container.httpProbe('readiness', '/-/ready', port='http') +
        container.httpProbe('liveness', '/-/healthy', port='http') +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.serviceAccount(app) +
      pod.volumeConfigMap('config', configmap=app) +
      pod.securityContext({ runAsUser: 65534, runAsGroup: 65534 }) +
      pod.affinity(global.affinity) +
      pod.tolerations(global.tolerations)
    ) +
    statefulset.volumeClaim('data', '100Gi'),
  ]
