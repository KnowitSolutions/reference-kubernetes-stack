function(config) {
  local grafana = config.grafana,
  local keycloak = config.keycloak,
  local postgres = grafana.postgres,

  sections: {
    server: {
      domain: grafana.external_address,
      root_url: '%s://%s' % [grafana.external_protocol, grafana.external_address],
    },

    database: if postgres.enabled then {
      type: 'postgres',
      host: postgres.address,
      name: postgres.database,
      ssl_mode:
        if !postgres.tls.enabled then 'disable'
        else if !postgres.tls.hostname_validation then 'require'
        else 'verify-full',
    } else {
      type: 'sqlite3',
    },

    auth: {
      oauth_auto_login: true,
      signout_redirect_url: '%s://%s/auth/realms/master/protocol/openid-connect/logout?redirect_uri=%s%%3A%%2F%%2F%s' % [
        keycloak.external_protocol,
        keycloak.external_address,
        grafana.external_protocol,
        grafana.external_address,
      ],
    },

    'auth.generic_oauth': {
      enabled: true,
      auth_url: '%s://%s/auth/realms/master/protocol/openid-connect/auth' % [keycloak.external_protocol, keycloak.external_address],
      token_url: 'http://%s:8080/auth/realms/master/protocol/openid-connect/token' % [keycloak.internal_address],
      api_url: 'http://%s:8080/auth/realms/master/protocol/openid-connect/userinfo' % [keycloak.internal_address],
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
