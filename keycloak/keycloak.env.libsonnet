function(app, config)
  local ns = config.keycloak.namespace;
  local keycloak = config.keycloak;
  local storage =
    if keycloak.storage == 'postgres' then keycloak.postgres
    else if keycloak.storage == 'mssql' then keycloak.mssql;

  {
    KEYCLOAK_USER: keycloak.admin.username,
    KEYCLOAK_PASSWORD: keycloak.admin.password,
    DB_VENDOR: keycloak.storage,
    DB_ADDR: storage.address,
    DB_PORT: std.toString(storage.port),
    DB_DATABASE: storage.database,
    DB_USER: storage.username,
    DB_PASSWORD: storage.password,
    [if storage.tls.enabled then 'JDBC_PARAMS']: 'sslmode=%s' % (
      if storage.tls.hostname_validation then 'verify-full' else 'require'
    ),
    JGROUPS_DISCOVERY_PROTOCOL: 'kubernetes.KUBE_PING',
    JGROUPS_DISCOVERY_PROPERTIES_DIRECT: '{namespace=>%s,labels=>app=%s,port_range=>0}' % [ns, app],
    KEYCLOAK_FRONTEND_URL: 'http://%s/auth' % [keycloak.external_address],
    PROXY_ADDRESS_FORWARDING: 'true',
    KEYCLOAK_STATISTICS: 'all',
  }
