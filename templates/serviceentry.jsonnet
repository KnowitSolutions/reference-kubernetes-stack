{
  all:: function(arr)
    local and = function(x, y) x && y;
    std.foldl(and, arr, true),

  isInt:: function(str)
    local range = std.range(std.codepoint('0'), std.codepoint('9'));
    local inRange = function(x) std.member(range, x);
    local codepoints = std.map(std.codepoint, str);
    $.all(std.map(inRange, codepoints)),

  isByte:: function(int)
    0 <= int && int < 256,

  isIp:: function(str)
    local octetsStr = std.split(str, '.');
    local isInts = $.all(std.map($.isInt, octetsStr));
    local octetsInt = std.map(std.parseInt, octetsStr);
    local isBytes = $.all(std.map($.isByte, octetsInt));
    isInts && isBytes && std.length(octetsInt) == 4,

  new(internal=false):: {
    apiVersion: 'networking.istio.io/v1beta1',
    kind: 'ServiceEntry',
    spec: {
      location: if internal then 'MESH_INTERNAL' else 'MESH_EXTERNAL',
      local addresses = std.map(function(ep) ep.address, self.endpoints),
      resolution:
        if std.length(self.endpoints) == 0 then 'NONE'
        else if $.all(std.map($.isIp, addresses)) then 'STATIC'
        else 'DNS',
      endpoints: [],
    },
  },

  host(address):: {
    spec+: {
      hosts+: [address],
    },
  },

  vip(address):: {
    spec+: {
      addresses+: [address],
    },
  },

  port(name, port, protocol='TCP'):: {
    spec+: {
      ports+: [
        {
          name: name,
          number: port,
          protocol: protocol,
        },
      ],
    },
  },

  endpoint(address):: {
    spec+: {
      endpoints+: [
        {
          address: address,
        },
      ],
    },
  },
}
