function(app, config)
  local ns = config.keycloak.namespace;
  local keycloak = config.keycloak;
  local postgres = keycloak.postgres;

  {
    KEYCLOAK_USER: keycloak.admin.username,
    KEYCLOAK_PASSWORD: keycloak.admin.password,
    DB_VENDOR: 'postgres',
    DB_ADDR: postgres.address,
    DB_PORT: std.toString(postgres.port),
    DB_DATABASE: postgres.database,
    DB_USER: postgres.username,
    DB_PASSWORD: postgres.password,
    [if postgres.tls.enabled then 'JDBC_PARAMS']: 'sslmode=%s' % (
      if postgres.tls.hostname_validation then 'verify-full' else 'require'
    ),
    JGROUPS_DISCOVERY_PROTOCOL: 'kubernetes.KUBE_PING',
    JGROUPS_DISCOVERY_PROPERTIES_DIRECT: '{namespace=>%s,labels=>app=%s,port_range=>0}' % [ns, app],
    KEYCLOAK_FRONTEND_URL: 'http://%s/auth' % [keycloak.external_address],
    PROXY_ADDRESS_FORWARDING: 'true',
    KEYCLOAK_STATISTICS: 'all',
  }
