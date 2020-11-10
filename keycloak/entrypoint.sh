#!/usr/bin/env bash

set -euo pipefail
export PATH="/opt/jboss/tools:/opt/jboss/tools/databases:/opt/jboss/keycloak/bin:$PATH"
. /tmp/configmap/environment.sh
. /tmp/secret/environment.sh

login() {
  kcadm.sh config credentials \
    --server http://localhost:8080/auth \
    --realm master \
    --user "$KEYCLOAK_USER" \
    --password "$KEYCLOAK_PASSWORD"
}

create_client() {
  local text=$(kcadm.sh create clients \
    --set clientId="$1" \
    --set secret="$2" \
    --set redirectUris="[\"$3\"]" 2>&1)
  local code=$?
  echo "$text"

  if [[ "$text" == "Client $1 already exists" ]]; then
    code=0;
  fi
  return $code
}

(
  trap "kill 1" EXIT
  until login; do sleep 10s; done
  create_client "$GRAFANA_CLIENT_ID" "$GRAFANA_CLIENT_SECRET" "$GRAFANA_CALLBACK_URL"
  create_client "$KIALI_CLIENT_ID" "$KIALI_CLIENT_SECRET" "$KIALI_CALLBACK_URL"
  create_client "$JAEGER_CLIENT_ID" "$JAEGER_CLIENT_SECRET" "$JAEGER_CALLBACK_URL"
  trap - EXIT
)&

if [[ "$DB_VENDOR" == "postgres" ]]; then
  DB_ADDR+=":$DB_PORT"
fi

add-user-keycloak.sh --user "$KEYCLOAK_USER" --password "$KEYCLOAK_PASSWORD"
. change-database.sh "$DB_VENDOR"
x509.sh
jgroups.sh
infinispan.sh
statistics.sh
autorun.sh
vault.sh

exec standalone.sh \
  -c=standalone-ha.xml \
  -Djboss.bind.address=0.0.0.0 \
  -Djboss.bind.address.private=0.0.0.0 \
  -Djboss.bind.address.management=0.0.0.0 \
  -Dkeycloak.frontendUrl="$KEYCLOAK_FRONTEND_URL"
