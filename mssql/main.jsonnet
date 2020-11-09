local metadata = import '../templates/metadata.jsonnet';
local serviceentry = import '../templates/serviceentry.jsonnet';

local app = 'mssql';

function(global, mssql)
  if mssql.externalAddress != null then [
    serviceentry.new() +
    metadata.new(app, global.namespace) +
    serviceentry.host(app) +
    serviceentry.vip(mssql.internalAddress) +
    serviceentry.endpoint(mssql.externalAddress) +
    serviceentry.port(app, mssql.port),
  ] else []
