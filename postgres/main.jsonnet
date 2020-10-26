local metadata = import '../templates/metadata.jsonnet';
local serviceentry = import '../templates/serviceentry.jsonnet';

local app = 'postgres';

function(config)
  local ns = config.postgres.namespace;
  local postgres = config.postgres;
  local vip = postgres.vip;

  if vip.enabled then [
    serviceentry.new() +
    metadata.new(app, ns=ns) +
    serviceentry.host(app) +
    serviceentry.vip(vip.internal_address) +
    serviceentry.endpoint(vip.external_address) +
    serviceentry.port(app, vip.port),
  ] else []
