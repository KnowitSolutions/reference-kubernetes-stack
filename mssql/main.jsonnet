local metadata = import '../templates/metadata.jsonnet';
local serviceentry = import '../templates/serviceentry.jsonnet';

local app = 'mssql';

function(config)
  local ns = config.mssql.namespace;
  local mssql = config.mssql;
  local vip = mssql.vip;

  if vip.enabled then [
    serviceentry.new() +
    metadata.new(app, ns=ns) +
    serviceentry.host(app) +
    serviceentry.vip(vip.internalAddress) +
    serviceentry.endpoint(vip.externalAddress) +
    serviceentry.port(app, vip.port),
  ] else []
