local configmap = import '../templates/configmap.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local secret = import '../templates/secret.jsonnet';
local collector = import 'collector.jsonnet';
local query = import 'query.jsonnet';
local scheme = import 'scheme.jsonnet';

local app = 'jaeger';

function(config)
  local ns = config.jaeger.namespace;
  local jaeger = config.jaeger;
  local cassandra = config.jaeger.cassandra;

  [
    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'collector.yaml': std.manifestYamlDoc((import 'collector.yaml.jsonnet')(config)),
      'query.yaml': std.manifestYamlDoc((import 'query.yaml.jsonnet')(config)),
    }),

    secret.new() +
    metadata.new(app, ns=ns) +
    secret.data({
      [if cassandra.username != null then 'CASSANDRA_USERNAME']: cassandra.username,
      [if cassandra.password != null then 'CASSANDRA_PASSWORD']: cassandra.password,
      clientID: jaeger.oidc.clientId,
      clientSecret: jaeger.oidc.clientSecret,
    }),
  ] +

  scheme(config) +
  collector(config) +
  query(config)
