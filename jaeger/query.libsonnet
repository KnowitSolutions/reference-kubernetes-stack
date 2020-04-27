local certificate = import '../templates/certificate.libsonnet';
local container = import '../templates/container.libsonnet';
local deployment = import '../templates/deployment.libsonnet';
local gateway = import '../templates/gateway.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local pod = import '../templates/pod.libsonnet';
local service = import '../templates/service.libsonnet';
local virtualservice = import '../templates/virtualservice.libsonnet';

local app = 'jaeger';
local query_app = 'jaeger-query';
local query_image = 'jaegertracing/jaeger-query:1.17.1';
local auth_app = 'oauth2-proxy';
local auth_image = 'quay.io/oauth2-proxy/oauth2-proxy:v5.1.0';

function(config)
  local ns = config.jaeger.namespace;
  local jaeger = config.jaeger;
  local keycloak = config.keycloak;

  (if jaeger.tls.acme then [certificate.new(jaeger.external_address)] else []) +
  [
    gateway.new(jaeger.external_address, tls=jaeger.tls.enabled) +
    metadata.new(app, ns=ns),

    virtualservice.new() +
    metadata.new(app, ns=ns) +
    virtualservice.host(jaeger.external_address) +
    virtualservice.gateway(app) +
    virtualservice.route(query_app, port=4180),

    service.new(query_app) +
    metadata.new(query_app, ns=ns) +
    service.port(4180) +
    service.port(16686, name='http-direct') +
    service.port(16687, name='http-telemetry'),

    deployment.new(replicas=jaeger.replicas) +
    metadata.new(query_app, ns=ns) +
    deployment.pod(
      pod.new() +
      metadata.annotations({
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '16687',
        'json-logs': 'true',
        'json-log-key': 'msg',
      }) +
      pod.container(
        container.new(query_app, query_image) +
        container.args(['--config-file', '/etc/jaeger/query.yaml']) +
        container.env_from(secret=app) +
        container.env({
          SPAN_STORAGE_TYPE: 'cassandra',
          JAEGER_DISABLED: 'true',
        }) +
        container.port('http-direct', 16686) +
        container.port('http-telemetry', 16687) +
        container.volume('config', '/etc/jaeger') +
        container.resources('100m', '100m', '128Mi', '128Mi') +
        container.http_probe('readiness', '/', port='http-direct') +
        container.http_probe('liveness', '/', port='http-telemetry')
      ) +
      pod.container(
        container.new(auth_app, auth_image) +
        container.args([
          '--upstream=http://127.0.0.1:16686',
          '--skip-provider-button',
          '--provider=oidc',
          '--skip-oidc-discovery=true',
          '--oidc-issuer-url=%s://%s/auth/realms/master' % [keycloak.external_protocol, keycloak.external_address],
          '--login-url=%s://%s/auth/realms/master/protocol/openid-connect/auth' % [keycloak.external_protocol, keycloak.external_address],
          '--redeem-url=http://%s:8080/auth/realms/master/protocol/openid-connect/token' % keycloak.internal_address,
          '--oidc-jwks-url=http://%s:8080/auth/realms/master/protocol/openid-connect/certs' % keycloak.internal_address,
          '--client-id=%s' % jaeger.oidc.client_id,
          '--client-secret=%s' % jaeger.oidc.client_secret,
          '--redirect-url=%s://%s/oauth2/callback' % [jaeger.external_protocol, jaeger.external_address],
          '--cookie-secret=secret',  // TODO: Change
          '--cookie-secure=false',
          '--email-domain=*',
        ]) +
        container.port('http', 4180) +
        // TODO: resources
        container.http_probe('readiness', '/ping') +
        container.http_probe('liveness', '/ping')
      ) +
      pod.volume_configmap('config', configmap=app) +
      pod.security_context({ runAsUser: 1000, runAsGroup: 1000 })
    ),
  ]
