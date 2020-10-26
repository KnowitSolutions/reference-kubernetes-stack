local container = import '../templates/container.jsonnet';
local deployment = import '../templates/deployment.jsonnet';
local destinationrule = import '../templates/destinationrule.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local pod = import '../templates/pod.jsonnet';
local role = import '../templates/role.jsonnet';
local rolebinding = import '../templates/rolebinding.jsonnet';
local service = import '../templates/service.jsonnet';
local serviceaccount = import '../templates/serviceaccount.jsonnet';

local app = 'kube-state-metrics';
local image = 'quay.io/coreos/kube-state-metrics:v1.9.5';

function(config)
  local ns = config.kubeStateMetrics.namespace;
  local kubeStateMetrics = config.kubeStateMetrics;

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
    destinationrule.circuitBreaker(),

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
        container.httpProbe('readiness', '/', port='http-telemetry') +
        container.httpProbe('liveness', '/healthz') +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.serviceAccount(app) +
      pod.securityContext({ runAsUser: 65534, runAsGroup: 65534 }) +
      pod.affinity(kubeStateMetrics.affinity) +
      pod.tolerations(kubeStateMetrics.tolerations)
    ),
  ]
