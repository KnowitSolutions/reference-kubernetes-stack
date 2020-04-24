local configmap = import '../templates/configmap.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local secret = import '../templates/secret.libsonnet';
local collector = import 'collector.libsonnet';
local query = import 'query.libsonnet';
local scheme = import 'scheme.libsonnet';

local app = 'jaeger';

function(config)
  local ns = config.jaeger.namespace;
  local jaeger = config.jaeger;
  local cassandra = config.jaeger.cassandra;

  [
    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'collector.yaml': std.manifestYamlDoc((import 'collector.yaml.libsonnet')(config)),
      'query.yaml': std.manifestYamlDoc((import 'query.yaml.libsonnet')(config)),
    }),

    secret.new() +
    metadata.new(app, ns=ns) +
    secret.data({
      [if cassandra.username != null then 'CASSANDRA_USERNAME']: cassandra.username,
      [if cassandra.password != null then 'CASSANDRA_PASSWORD']: cassandra.password,
    }),
  ] +

  scheme(config) +
  collector(config) +
  query(config)
