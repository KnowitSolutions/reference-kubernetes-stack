function(global, grafana, sql, keycloak) {
  sections: {
    server: {
      domain: grafana.externalAddress,
      root_url: '%s://%s' % [if global.tls then 'https' else 'http', grafana.externalAddress],
    },

    database: if sql.vendor == 'postgres' then {
      type: 'postgres',
      host: sql.address,
      name: grafana.database,
      ssl_mode:
        if !sql.tls.enabled then 'disable'
        else if !sql.tls.hostnameValidation then 'require'
        else 'verify-full',
    } else {
      type: 'sqlite3',
    },

    auth: {
      oauth_auto_login: true,
      signout_redirect_url: '%s://%s/auth/realms/master/protocol/openid-connect/logout?redirect_uri=%s%%3A%%2F%%2F%s' % [
        if global.tls then 'https' else 'http',
        keycloak.externalAddress,
        if global.tls then 'https' else 'http',
        grafana.externalAddress,
      ],
    },

    'auth.generic_oauth': {
      enabled: true,
      auth_url: '%s://%s/auth/realms/master/protocol/openid-connect/auth' % [if global.tls then 'https' else 'http', keycloak.externalAddress],
      token_url: 'http://%s:8080/auth/realms/master/protocol/openid-connect/token' % [keycloak.internalAddress],
      api_url: 'http://%s:8080/auth/realms/master/protocol/openid-connect/userinfo' % [keycloak.internalAddress],
      role_attribute_path: 'contains(roles, "admin") && "Admin" || "Editor"',
    },

    security: {
      disable_gravatar: true,
    },

    analytics: {
      reporting_enabled: false,
      check_for_updates: false,
    },
  },
}
