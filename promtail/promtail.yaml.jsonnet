function(promtail) {
  server: { http_listen_port: 8080 },
  clients: [{ url: 'http://loki:8080/loki/api/v1/push' }],
  positions: { filename: '/var/lib/promtail/positions.yaml' },
  scrape_configs: [{
    job_name: 'kubernetes',
    kubernetes_sd_configs: [{ role: 'pod' }],
    relabel_configs: [
      {
        source_labels: [
          '__meta_kubernetes_namespace',
          '__meta_kubernetes_pod_name',
          '__meta_kubernetes_pod_uid',
          '__meta_kubernetes_pod_container_name',
        ],
        regex: '(.*);(.*);(.*);(.*)',
        replacement: '/var/log/pods/${1}_${2}_${3}/${4}/*.log',
        target_label: '__path__',
      },
      {
        source_labels: [
          '__meta_kubernetes_pod_annotation_prometheus_io_skip_labels',
          '__meta_kubernetes_pod_node_name',
        ],
        regex: '(?:|false);(.+)',
        target_label: 'node',
      },
      {
        source_labels: [
          '__meta_kubernetes_pod_annotation_prometheus_io_skip_labels',
          '__meta_kubernetes_namespace',
        ],
        regex: '(?:|false);(.+)',
        target_label: 'namespace',
      },
      {
        source_labels: [
          '__meta_kubernetes_pod_annotation_prometheus_io_skip_labels',
          '__meta_kubernetes_pod_name',
        ],
        regex: '(?:|false);(.+)',
        target_label: 'pod',
      },
      {
        source_labels: [
          '__meta_kubernetes_pod_annotation_prometheus_io_skip_labels',
          '__meta_kubernetes_pod_container_name',
        ],
        regex: '(?:|false);(.+)',
        target_label: 'container',
      },
      {
        source_labels: [
          '__meta_kubernetes_pod_annotation_prometheus_io_skip_labels',
          '__meta_kubernetes_pod_label_app',
        ],
        regex: '(?:|false);(.+)',
        target_label: 'app',
      },
      {
        source_labels: [
          '__meta_kubernetes_pod_annotation_prometheus_io_skip_labels',
          '__meta_kubernetes_pod_label_version',
        ],
        regex: '(?:|false);(.+)',
        target_label: 'version',
      },
    ],
    pipeline_stages:
      if promtail.logType == 'cri' then [{ cri: {} }]
      else if promtail.logType == 'docker' then [{ docker: {} }]
      else if promtail.logType == 'raw' then []
      else error 'Invalid Promtail log format',
  }],
}
