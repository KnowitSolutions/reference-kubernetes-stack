local configmap = import '../templates/configmap.libsonnet';
local container = import '../templates/container.libsonnet';
local destinationrule = import '../templates/destinationrule.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local pod = import '../templates/pod.libsonnet';
local role = import '../templates/role.libsonnet';
local rolebinding = import '../templates/rolebinding.libsonnet';
local service = import '../templates/service.libsonnet';
local serviceaccount = import '../templates/serviceaccount.libsonnet';
local statefulset = import '../templates/statefulset.libsonnet';

local app = 'prometheus';
local image = 'prom/prometheus:v2.15.2';

function(config)
  local ns = config.prometheus.namespace;

  [
    serviceaccount.new() +
    metadata.new(app, ns=ns),

    role.new(cluster=true) +
    metadata.new(app) +
    role.rule({
      apiGroups: [''],
      verbs: ['get', 'list', 'watch'],
      resources: [
        'nodes',
        'nodes/proxy',
        'services',
        'endpoints',
        'pods',
      ],
    }) +
    role.rule({
      nonResourceURLs: ['/metrics'],
      verbs: ['get'],
    }),

    rolebinding.new(cluster=true) +
    metadata.new(app) +
    rolebinding.role(app, cluster=true) +
    rolebinding.subject('ServiceAccount', app, ns=ns),

    service.new(app) +
    metadata.new(app, ns=ns) +
    service.port(9090),

    destinationrule.new(app) +
    metadata.new(app, ns=ns) +
    destinationrule.sticky(),

    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'prometheus.yml': importstr 'prometheus.yml',
    }),

    statefulset.new(replicas=2, parallel=true) +
    metadata.new(app, ns=ns) +
    statefulset.pod(
      pod.new() +
      pod.container(
        container.new(app, image) +
        container.port('http', 9090) +
        container.volume('config', '/etc/prometheus') +
        container.volume('data', '/prometheus') +
        container.resources(memory_request='400Mi') +
        container.http_probe('readiness', '/-/ready') +
        container.http_probe('liveness', '/-/healthy')
      ) +
      pod.service_account(app) +
      pod.volume_configmap('config', configmap=app) +
      pod.security_context({ runAsUser: 65534 })
    ) +
    statefulset.volume_claim('data', '50Gi'),
  ]
