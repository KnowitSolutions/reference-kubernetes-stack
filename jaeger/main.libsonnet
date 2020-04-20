local configmap = import '../templates/configmap.libsonnet';
local metadata = import '../templates/metadata.libsonnet';
local collector = import 'collector.libsonnet';
local query = import 'query.libsonnet';
local scheme = import 'scheme.libsonnet';

local app = 'jaeger';

function(config)
  local ns = config.jaeger.namespace;

  [
    configmap.new() +
    metadata.new(app, ns=ns) +
    configmap.data({
      'collector.yaml': std.manifestYamlDoc((import 'collector.yaml.libsonnet')(config)),
      'query.yaml': std.manifestYamlDoc((import 'query.yaml.libsonnet')(config)),
    }),
  ] +

  scheme(config) +
  collector(config) +
  query(config)
