function(config) {
  local grafana = config.grafana,
  local keycloak = config.keycloak,

  sections: {
    server: {
      domain: grafana.external_address,
      root_url: 'http://%s' % [grafana.external_address],
    },

    auth: {
      oauth_auto_login: true,
      signout_redirect_url: 'http://%(keycloak)s/auth/realms/master/protocol/openid-connect/logout?redirect_uri=http%%3A%%2F%%2F%(grafana)s' % {
        grafana: grafana.external_address,
        keycloak: keycloak.external_address,
      },
    },

    'auth.generic_oauth': {
      enabled: true,
      client_id: grafana.oidc.client_id,
      client_secret: grafana.oidc.client_secret,
      auth_url: 'http://%s/auth/realms/master/protocol/openid-connect/auth' % [keycloak.external_address],
      token_url: 'http://%s:8080/auth/realms/master/protocol/openid-connect/token' % [keycloak.internal_address],
      api_url: 'http://%s:8080/auth/realms/master/protocol/openid-connect/userinfo' % [keycloak.internal_address],
      role_attribute_path: 'contains(roles, "admin") && "Admin" || "Viewer"',
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
