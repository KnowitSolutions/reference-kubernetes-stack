local kubernetesMixin = import 'github.com/kubernetes-monitoring/kubernetes-mixin/mixin.libsonnet';

local reduce = function(arr) std.foldl(function(a, b) a + b, arr, {});
local base = kubernetesMixin {
  _config+:: {
    kubeApiserverSelector: 'job="kubernetes-apiservers"',
    kubeletSelector: 'job="kubernetes-nodes"',
    cadvisorSelector: 'job="kubernetes-nodes-cadvisor"',
    // TODO: kubeControllerManagerSelector: 'job="kubernetes-controller-managers"',
    // TODO: kubeSchedulerSelector: 'job="kubernetes-schedulers"',
    // TODO: kubeProxySelector: 'job="kubernetes-proxies"',

    nodeExporterSelector: 'job="kubernetes-pods"',
    kubeStateMetricsSelector: 'job="kubernetes-pods"',

    grafanaK8s+:: {
      dashboardNamePrefix: '',
      dashboardTags: [],
    },
  },
};

{
  prometheusAlerts: {
    groups: [
      alert
      for alert in base.prometheusAlerts.groups
      if !std.setMember(alert.name, std.set([
        'kubernetes-system-controller-manager',
        'kubernetes-system-scheduler',
      ]))
    ],
  },

  prometheusRules: {
    groups: [
      rule
      for rule in base.prometheusRules.groups
      if !std.setMember(rule.name, std.set([
        'kube-scheduler.rules',
      ]))
    ],
  },

  grafanaDashboards: reduce([
    { [dashboard]: base.grafanaDashboards[dashboard] }
    for dashboard in std.objectFields(base.grafanaDashboards)
    if !std.setMember(dashboard, std.set([
      'controller-manager.json',
      'scheduler.json',
      'proxy.json',
    ]))
  ]),
}
