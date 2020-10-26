function(config) {
  local grafana = config.grafana,
  local keycloak = config.keycloak,
  local postgres = grafana.postgres,

  sections: {
    server: {
      domain: grafana.externalAddress,
      root_url: '%s://%s' % [grafana.externalProtocol, grafana.externalAddress],
    },

    database: if postgres.enabled then {
      type: 'postgres',
      host: postgres.address,
      name: postgres.database,
      ssl_mode:
        if !postgres.tls.enabled then 'disable'
        else if !postgres.tls.hostnameValidation then 'require'
        else 'verify-full',
    } else {
      type: 'sqlite3',
    },

    auth: {
      oauth_auto_login: true,
      signout_redirect_url: '%s://%s/auth/realms/master/protocol/openid-connect/logout?redirect_uri=%s%%3A%%2F%%2F%s' % [
        keycloak.externalProtocol,
        keycloak.externalAddress,
        grafana.externalProtocol,
        grafana.externalAddress,
      ],
    },

    'auth.generic_oauth': {
      enabled: true,
      auth_url: '%s://%s/auth/realms/master/protocol/openid-connect/auth' % [keycloak.externalProtocol, keycloak.externalAddress],
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
