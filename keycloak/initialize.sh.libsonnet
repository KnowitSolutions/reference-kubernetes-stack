function(config) |||
  #!/bin/bash
  set -e
  export PATH="/opt/jboss/keycloak/bin:$PATH"

  kcadm.sh config credentials \
    --server http://keycloak:8080/auth \
    --realm master \
    --user admin \
    --password admin

  admin_id=$(
    kcadm.sh get users \
      --fields id \
      --query username=admin \
      --format csv | \
    tr -d '"'
  )

  kcadm.sh update "users/$admin_id" \
    --set email=admin@localhost \
    --set emailVerified=true

  client_id=$(
    kcadm.sh create clients \
      --id \
      --set clientId='%(grafana_client_id)s' \
      --set secret='%(grafana_client_secret)s' \
      --set redirectUris='["http://%(grafana_address)s/*"]'
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

  curl --request POST --silent --fail http://localhost:15020/quitquitquit
||| % {
  grafana_client_id: config.grafana.oidc.client_id,
  grafana_client_secret: config.grafana.oidc.client_secret,
  grafana_address: config.grafana.external_address,
}
