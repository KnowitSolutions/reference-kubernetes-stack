#!/usr/bin/env bash
set -euo pipefail

. /tmp/configmap/environment.sh
. /tmp/secret/environment.sh

if [[ "$DB_VENDOR" == "postgres" ]]; then
  DB_ADDR+=":$DB_PORT"
fi

/opt/jboss/keycloak/bin/add-user-keycloak.sh --user "$KEYCLOAK_USER" --password "$KEYCLOAK_PASSWORD"
. /opt/jboss/tools/databases/change-database.sh "$DB_VENDOR"
/opt/jboss/tools/x509.sh
/opt/jboss/tools/jgroups.sh
/opt/jboss/tools/infinispan.sh
/opt/jboss/tools/statistics.sh
/opt/jboss/tools/autorun.sh
/opt/jboss/tools/vault.sh

kcadm='/opt/jboss/keycloak/bin/kcadm.sh'

login() {
  local srv='http://localhost:8080/auth'
  "$kcadm" config credentials --server "$srv" --realm master --user "$1" --password "$2"
}

set_email() {
  local id="$("$kcadm" get users --query username="$1" --format csv --fields id | tr -d '"')"
  local verified=$("$kcadm" get "users/$id" --format csv --fields emailVerified)
  if [[ "$verified" == "false" ]]; then
    "$kcadm" update "users/$id" --set email="$2" --set emailVerified=true
  else
    echo "Email is already verified"
  fi
}

create_client() {
  local text="$("$kcadm" create clients \
    --set clientId="$2" \
    --set publicClient=$([[ "$1" == 'public' ]] && echo 'true' || echo 'false') \
    --set secret="$3" \
    --set standardFlowEnabled=$([[ "$1" == 'confidential' ]] && echo 'true' || echo 'false') \
    --set implicitFlowEnabled=$([[ "$1" == 'public' ]] && echo 'true' || echo 'false') \
    --set redirectUris="$4" \
    --set fullScopeAllowed=false 2>&1)" && \
  local code=$? || local code=$?

  echo "$text"
  if [[ "$text" == "Client $2 already exists" ]]; then
    code=0
  fi
  return $code
}

create_userinfo_roles_mapper() {
  local id="$("$kcadm" get clients --query clientId="$1" --format csv --fields id | tr -d '"')"
  local text=$("$kcadm" create "clients/$id/protocol-mappers/models" \
    --set protocol=openid-connect \
    --set name=Roles \
    --set protocolMapper=oidc-usermodel-realm-role-mapper \
    --set config.multivalued=true \
    --set 'config."claim.name"=roles' \
    --set 'config."jsonType.label"=String' \
    --set 'config."userinfo.token.claim"=true') && \
  local code=$? || local code=$?

  echo "$text"
  if [[ "$text" == "Protocol mapper exists with same name" ]]; then
    code=0
  fi
  return $code
}

add_scope() {
  local client_id="$("$kcadm" get clients --query clientId="$1" --format csv --fields id | tr -d '"')"
  local role_id="$("$kcadm" get roles --format csv --fields id,name | grep "\"$2\"\$" | cut -f 1 -d , | tr -d '"')"
  "$kcadm" create "clients/$client_id/scope-mappings/realm" --body "[{\"id\":\"$role_id\"}]"
}

failed() {
  echo 'Migration failed. Exiting...'
  kill 1
}

(
  trap failed EXIT
  until login "$KEYCLOAK_USER" "$KEYCLOAK_PASSWORD"; do sleep 10s; done
  echo "Applying migrations"
  set_email "$KEYCLOAK_USER" 'admin@localhost'
  create_client confidential "$GRAFANA_CLIENT_ID" "$GRAFANA_CLIENT_SECRET" "[\"$GRAFANA_URL\",\"$GRAFANA_CALLBACK_URL\"]"
  create_userinfo_roles_mapper "$GRAFANA_CLIENT_ID"
  add_scope "$GRAFANA_CLIENT_ID" 'admin'
  create_client public "$KIALI_CLIENT_ID" "" "[\"$KIALI_CALLBACK_URL\"]"
  trap - EXIT
)&

for addr in $(hostname --all-ip-addresses)
do
    bind+="-Djboss.bind.address=$addr -Djboss.bind.address.private=$addr "
done

exec /opt/jboss/keycloak/bin/standalone.sh \
  -Dkeycloak.frontendUrl=$KEYCLOAK_FRONTEND_URL \
  $bind \
  -Djboss.bind.address.management=0.0.0.0 \
  -c=standalone-ha.xml \
  -b 0.0.0.0
