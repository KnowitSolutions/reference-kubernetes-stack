function(global, keycloak, sql, grafana, kiali, jaeger)
  (import 'keycloak.jsonnet')(global, keycloak, sql) +
  (import 'initialize.jsonnet')(global, keycloak, grafana, kiali, jaeger)
