function(global, keycloak, sql)
  {
    configmap: {
      DB_VENDOR: sql.vendor,
      DB_ADDR: sql.address,
      DB_PORT: std.toString(sql.port),
      DB_DATABASE: keycloak.database,
      [if sql.tls.enabled then 'JDBC_PARAMS']: 'sslmode=%s' % (
        if sql.tls.hostnameValidation then 'verify-full' else 'require'
      ),
      JGROUPS_DISCOVERY_PROTOCOL: 'kubernetes.KUBE_PING',
      JGROUPS_DISCOVERY_PROPERTIES_DIRECT: '{namespace=>%s,labels=>app=keycloak,port_range=>0}' % global.namespace,
      KEYCLOAK_FRONTEND_URL: '%s://%s/auth' % [if global.tls then 'https' else 'http', keycloak.externalAddress],
      PROXY_ADDRESS_FORWARDING: 'true',
      KEYCLOAK_STATISTICS: 'all',
    },
    secret: {
      DB_USER: sql.username,
      DB_PASSWORD: sql.password,
      KEYCLOAK_USER: keycloak.admin.username,
      KEYCLOAK_PASSWORD: keycloak.admin.password,
    },
  }
