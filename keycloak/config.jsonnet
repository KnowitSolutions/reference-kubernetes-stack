local manifestExport = function(vars) std.join('\n', [
  local value = std.strReplace(vars[name], "'", "'\"'\"'");
  'export ' + name + "='" + value + "'"
  for name in std.objectFields(vars)
]);

function(global, keycloak, sql, grafana, kiali, jaeger)
  {
    configmap: manifestExport({
      DB_VENDOR: sql.vendor,
      DB_ADDR: sql.address,
      DB_PORT: std.toString(sql.port),
      DB_DATABASE: keycloak.database,
      [if sql.tls.enabled then 'JDBC_PARAMS']: '?sslmode=%s' % (if sql.tls.hostnameValidation then 'verify-full' else 'require'),

      JGROUPS_DISCOVERY_PROTOCOL: 'kubernetes.KUBE_PING',
      JGROUPS_DISCOVERY_PROPERTIES_DIRECT: '{namespace=>%s,labels=>app=keycloak,port_range=>0}' % global.namespace,

      KEYCLOAK_FRONTEND_URL: '%s://%s/auth' % [if global.tls then 'https' else 'http', keycloak.externalAddress],
      PROXY_ADDRESS_FORWARDING: 'true',

      KEYCLOAK_STATISTICS: 'all',

      GRAFANA_URL: (if global.tls then 'https://' else 'http://') + grafana.externalAddress,
      GRAFANA_CALLBACK_URL: (if global.tls then 'https://' else 'http://') + grafana.externalAddress + '/login/generic_oauth',
      KIALI_CALLBACK_URL: (if global.tls then 'https://' else 'http://') + kiali.externalAddress + '/oidc/callback',
      JAEGER_CALLBACK_URL: (if global.tls then 'https://' else 'http://') + jaeger.externalAddress + '/oidc/callback',
    }),
    secret: manifestExport({
      DB_USER: sql.username,
      DB_PASSWORD: sql.password,

      KEYCLOAK_USER: keycloak.admin.username,
      KEYCLOAK_PASSWORD: keycloak.admin.password,

      GRAFANA_CLIENT_ID: grafana.oidc.clientId,
      GRAFANA_CLIENT_SECRET: grafana.oidc.clientSecret,
      KIALI_CLIENT_ID: kiali.oidc.clientId,
      KIALI_CLIENT_SECRET: kiali.oidc.clientSecret,
      JAEGER_CLIENT_ID: jaeger.oidc.clientId,
      JAEGER_CLIENT_SECRET: jaeger.oidc.clientSecret,
    }),
    entrypoint: importstr 'entrypoint.sh',
  }
