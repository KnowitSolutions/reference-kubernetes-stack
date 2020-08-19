local container = import '../templates/container.libsonnet';
local deployment = import '../templates/deployment.libsonnet';
local destinationrule = import '../templates/destinationrule.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local pod = import '../templates/pod.libsonnet';
local role = import '../templates/role.libsonnet';
local rolebinding = import '../templates/rolebinding.libsonnet';
local service = import '../templates/service.libsonnet';
local serviceaccount = import '../templates/serviceaccount.libsonnet';

local app = 'kube-state-metrics';
local image = 'quay.io/coreos/kube-state-metrics:v1.9.5';

function(config)
  local ns = config.kube_state_metrics.namespace;
  local kube_state_metrics = config.kube_state_metrics;

  [
    serviceaccount.new() +
    metadata.new(app, ns=ns),

    role.new(cluster=true) +
    metadata.new('%s-%s' % [app, ns]) +
    role.rule({
      apiGroups: [''],
      verbs: ['list', 'watch'],
      resources: [
        'configmaps',
        'secrets',
        'nodes',
        'pods',
        'services',
        'resourcequotas',
        'replicationcontrollers',
        'limitranges',
        'persistentvolumeclaims',
        'persistentvolumes',
        'namespaces',
        'endpoints',
      ],
    }) +
    role.rule({
      apiGroups: ['extensions'],
      verbs: ['list', 'watch'],
      resources: [
        'daemonsets',
        'deployments',
        'replicasets',
        'ingresses',
      ],
    }) +
    role.rule({
      apiGroups: ['apps'],
      verbs: ['list', 'watch'],
      resources: [
        'statefulsets',
        'daemonsets',
        'deployments',
        'replicasets',
      ],
    }) +
    role.rule({
      apiGroups: ['batch'],
      verbs: ['list', 'watch'],
      resources: [
        'cronjobs',
        'jobs',
      ],
    }) +
    role.rule({
      apiGroups: ['autoscaling'],
      verbs: ['list', 'watch'],
      resources: [
        'horizontalpodautoscalers',
      ],
    }) +
    role.rule({
      apiGroups: ['authentication.k8s.io'],
      verbs: ['create'],
      resources: [
        'tokenreviews',
      ],
    }) +
    role.rule({
      apiGroups: ['authorization.k8s.io'],
      verbs: ['create'],
      resources: [
        'subjectaccessreviews',
      ],
    }) +
    role.rule({
      apiGroups: ['policy'],
      verbs: ['list', 'watch'],
      resources: [
        'poddisruptionbudgets',
      ],
    }) +
    role.rule({
      apiGroups: ['certificates.k8s.io'],
      verbs: ['list', 'watch'],
      resources: [
        'certificatesigningrequests',
      ],
    }) +
    role.rule({
      apiGroups: ['storage.k8s.io'],
      verbs: ['list', 'watch'],
      resources: [
        'storageclasses',
        'volumeattachments',
      ],
    }) +
    role.rule({
      apiGroups: ['admissionregistration.k8s.io'],
      verbs: ['list', 'watch'],
      resources: [
        'mutatingwebhookconfigurations',
        'validatingwebhookconfigurations',
      ],
    }) +
    role.rule({
      apiGroups: ['networking.k8s.io'],
      verbs: ['list', 'watch'],
      resources: [
        'networkpolicies',
      ],
    }) +
    role.rule({
      apiGroups: ['coordination.k8s.io'],
      verbs: ['list', 'watch'],
      resources: [
        'leases',
      ],
    }),

    rolebinding.new(cluster=true) +
    metadata.new('%s-%s' % [app, ns]) +
    rolebinding.role('%s-%s' % [app, ns], cluster=true) +
    rolebinding.subject('ServiceAccount', app, ns=ns),

    destinationrule.new(app) +
    metadata.new(app, ns=ns) +
    destinationrule.circuit_breaker(),

    service.new(app) +
    metadata.new(app, ns=ns) +
    service.port(8080) +
    service.port(8081, name='http-telemetry'),

    deployment.new() +
    metadata.new(app, ns=ns) +
    deployment.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
      }) +
      pod.container(
        container.new(app, image) +
        container.port('http', 8080) +
        container.port('http-telemetry', 8081) +
        container.resources('10m', '10m', '128Mi', '128Mi') +
        container.http_probe('readiness', '/', port='http-telemetry') +
        container.http_probe('liveness', '/healthz') +
        container.security_context({ readOnlyRootFilesystem: true })
      ) +
      pod.service_account(app) +
      pod.security_context({ runAsUser: 65534, runAsGroup: 65534 }) +
      pod.node_selector(kube_state_metrics.node_selector) +
      pod.tolerations(kube_state_metrics.node_tolerations)
    ),
  ]
