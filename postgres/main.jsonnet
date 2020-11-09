local metadata = import '../templates/metadata.jsonnet';
local serviceentry = import '../templates/serviceentry.jsonnet';

local app = 'postgres';

function(global, postgres)
  if postgres.externalAddress != null then [
    serviceentry.new() +
    metadata.new(app, global.namespace) +
    serviceentry.host(app) +
    serviceentry.vip(postgres.internalAddress) +
    serviceentry.endpoint(postgres.externalAddress) +
    serviceentry.port(app, postgres.port),
  ] else []
