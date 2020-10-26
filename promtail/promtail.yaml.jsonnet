function(config) {
  local promtail = config.promtail,

  server: {
    http_listen_port: 8080,
  },

  clients: [
    { url: 'http://loki:8080/loki/api/v1/push' },
  ],

  positions: {
    filename: '/var/lib/promtail/positions.yaml',
  },

  scrape_configs: [
    {
      job_name: 'kubernetes',
      kubernetes_sd_configs: [{ role: 'pod' }],

      relabel_configs: [
        {
          action: 'labelmap',
          regex: '__meta_kubernetes_pod_annotation_(.+)',
        },
        {
          action: 'labelmap',
          regex: '__meta_kubernetes_pod_label_(.+)',
        },
        {
          source_labels: ['__meta_kubernetes_namespace'],
          target_label: 'namespace',
        },
        {
          source_labels: ['__meta_kubernetes_pod_name'],
          target_label: 'pod',
        },
        {
          source_labels: ['__meta_kubernetes_pod_container_name'],
          target_label: 'container',
        },
        {
          source_labels: ['__meta_kubernetes_pod_node_name'],
          target_label: 'node',
        },
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
      ],

      pipeline_stages: (
        if promtail.logType == 'cri' then [{ cri: {} }]
        else if promtail.logType == 'docker' then [{ docker: {} }]
        else if promtail.logType == 'raw' then []
        else error 'Invalid Promtail log format'
      ) + [
        {
          match: {
            selector: '{json_logs="true"}',
            stages: [
              {
                regex: {
                  expression: '^(?P<json>.*)$',
                },
              },
              {
                template: {
                  source: 'data',
                  template: @'{{ Replace .json (print "\"" .json_log_key "\":") "\"output\":" -1 }}',
                },
              },
              {
                json: {
                  source: 'data',
                  expressions: {
                    level: null,
                    output: null,
                    request_id: 'requestId',
                  },
                },
              },
              {
                output: {
                  source: 'output',
                },
              },
              {
                labels: {
                  json: null,
                  level: null,
                  request_id: null,
                },
              },
            ],
          },
        },
      ],
    },
  ],
}
