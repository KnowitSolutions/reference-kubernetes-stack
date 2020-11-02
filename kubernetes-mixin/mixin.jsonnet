local kubernetesMixin = import 'github.com/kubernetes-monitoring/kubernetes-mixin/mixin.libsonnet';

kubernetesMixin {
  _config+:: {
    kubeApiserverSelector: 'job="kubernetes-apiservers"',
    // TODO: kubeControllerManagerSelector: 'job="kubernetes-controller-managers"',
    // TODO: kubeSchedulerSelector: 'job="kubernetes-schedulers"',
    // TODO: kubeProxySelector: 'job="kubernetes-proxies"',

    kubeletSelector: 'job="kubernetes-nodes"',
    cadvisorSelector: 'job="kubernetes-nodes-cadvisor"',

    nodeExporterSelector: 'job="kubernetes-pods",kubernetes_namespace="base",app="node-exporter"',
    kubeStateMetricsSelector: 'job="kubernetes-pods",kubernetes_namespace="base",app="kube-state-metrics"',

    grafanaK8s+:: {
      dashboardNamePrefix: '',
      dashboardTags: [],
    },
  },
}
