local metadata = import '../templates/metadata.libsonnet';
local serviceentry = import '../templates/serviceentry.libsonnet';

local app = 'mssql';

function(config)
  local ns = config.mssql.namespace;
  local mssql = config.mssql;
  local vip = mssql.vip;

  if vip.enabled then [
    serviceentry.new() +
    metadata.new(app, ns=ns) +
    serviceentry.host(app) +
    serviceentry.vip(vip.internal_address) +
    serviceentry.endpoint(vip.external_address) +
    serviceentry.port(app, vip.port),
  ] else []
