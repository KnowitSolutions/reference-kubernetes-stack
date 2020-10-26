function(config) |||
  #!/bin/bash
  set -e
  export PATH="/opt/jboss/keycloak/bin:$PATH"

  kcadm.sh config credentials \
    --server http://keycloak:8080/auth \
    --realm master \
    --user "$KEYCLOAK_USER" \
    --password "$KEYCLOAK_PASSWORD"

  admin_id=$(
    kcadm.sh get users \
      --fields id \
      --query username="$KEYCLOAK_USER" \
      --format csv | \
    tr -d '"'
  )

  kcadm.sh update "users/$admin_id" \
    --set email=admin@localhost \
    --set emailVerified=true

  client_id=$(
    kcadm.sh create clients \
      --id \
      --set clientId="$GRAFANA_GF_AUTH_GENERIC_OAUTH_CLIENT_ID" \
      --set secret="$GRAFANA_GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET" \
      --set redirectUris='["%(grafanaUrl)s/*"]'
  )
  echo "Created new client with id '$client_id'"

  kcadm.sh create "clients/$client_id/protocol-mappers/models" \
    --set protocol=openid-connect \
    --set name=Roles \
    --set protocolMapper=oidc-usermodel-realm-role-mapper \
    --set config.multivalued=true \
    --set 'config."claim.name"=roles' \
    --set 'config."jsonType.label"=String' \
    --set 'config."userinfo.token.claim"=true'

  client_id=$(
    kcadm.sh create clients \
      --id \
      --set clientId="$KIALI_clientID" \
      --set secret="$KIALI_clientSecret" \
      --set redirectUris='["%(kialiUrl)s/*"]'
  )
  echo "Created new client with id '$client_id'"

  client_id=$(
    kcadm.sh create clients \
      --id \
      --set clientId="$JAEGER_clientID" \
      --set secret="$JAEGER_clientSecret" \
      --set redirectUris='["%(jaegerUrl)s/*"]'
  )
  echo "Created new client with id '$client_id'"

  curl --request POST --silent --fail http://localhost:15020/quitquitquit
||| % {
  grafanaUrl: '%s://%s' % [config.grafana.externalProtocol, config.grafana.externalAddress],
  kialiUrl: '%s://%s' % [config.kiali.externalProtocol, config.kiali.externalAddress],
  jaegerUrl: '%s://%s' % [config.jaeger.externalProtocol, config.jaeger.externalAddress],
}
