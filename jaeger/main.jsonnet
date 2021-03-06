local configmap = import '../templates/configmap.jsonnet';
local metadata = import '../templates/metadata.jsonnet';
local secret = import '../templates/secret.jsonnet';

local app = 'jaeger';

function(global, jaeger, cassandra)
  [
    configmap.new() +
    metadata.new(app, global.namespace) +
    configmap.data({
      'collector.yaml': std.manifestYamlDoc((import 'collector.yaml.jsonnet')(jaeger, cassandra)),
      'query.yaml': std.manifestYamlDoc((import 'query.yaml.jsonnet')(jaeger, cassandra)),
    }),

    secret.new() +
    metadata.new(app, global.namespace) +
    secret.data({
      [if cassandra.username != null then 'CASSANDRA_USERNAME']: cassandra.username,
      [if cassandra.password != null then 'CASSANDRA_PASSWORD']: cassandra.password,
    }),
  ] +

  (import 'collector.jsonnet')(global, jaeger, cassandra) +
  (import 'query.jsonnet')(global, jaeger, cassandra)
