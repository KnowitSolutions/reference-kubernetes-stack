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

function(global)
  [
    serviceaccount.new() +
    metadata.new(app, global.namespace),

    role.new(cluster=true) +
    metadata.new(app + '-' + global.namespace) +
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
    metadata.new(app + '-' + global.namespace) +
    rolebinding.role(app + '-' + global.namespace, cluster=true) +
    rolebinding.subject('ServiceAccount', app, global.namespace),

    destinationrule.new(app) +
    metadata.new(app, global.namespace) +
    destinationrule.circuitBreaker(),

    service.new(app) +
    metadata.new(app, global.namespace) +
    service.port(8080) +
    service.port(8081, name='http-telemetry'),

    deployment.new() +
    metadata.new(app, global.namespace) +
    deployment.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '8080',
        'prometheus.io/skip-labels': 'true',
      }) +
      pod.container(
        container.new(app, image) +
        container.port('http', 8080) +
        container.port('http-telemetry', 8081) +
        container.resources('10m', '20m', '128Mi', '128Mi') +
        container.httpProbe('readiness', '/', port='http-telemetry') +
        container.httpProbe('liveness', '/healthz') +
        container.securityContext({ readOnlyRootFilesystem: true })
      ) +
      pod.serviceAccount(app) +
      pod.securityContext({ runAsUser: 65534, runAsGroup: 65534 }) +
      pod.affinity(global.affinity) +
      pod.tolerations(global.tolerations)
    ),
  ]
