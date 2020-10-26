{
  all:: function(arr)
    local and = function(x, y) x && y;
    std.foldl(and, arr, true),

  is_int:: function(str)
    local range = std.range(std.codepoint('0'), std.codepoint('9'));
    local in_range = function(x) std.member(range, x);
    local codepoints = std.map(std.codepoint, str);
    $.all(std.map(in_range, codepoints)),

  is_byte:: function(int)
    0 <= int && int < 256,

  is_ip:: function(str)
    local octets_str = std.split(str, '.');
    local is_ints = $.all(std.map($.is_int, octets_str));
    local octets_int = std.map(std.parseInt, octets_str);
    local is_bytes = $.all(std.map($.is_byte, octets_int));
    is_ints && is_bytes && std.length(octets_int) == 4,

  new(internal=false):: {
    apiVersion: 'networking.istio.io/v1beta1',
    kind: 'ServiceEntry',
    spec: {
      location: if internal then 'MESH_INTERNAL' else 'MESH_EXTERNAL',
      local addresses = std.map(function(ep) ep.address, self.endpoints),
      resolution:
        if std.length(self.endpoints) == 0 then 'NONE'
        else if $.all(std.map($.is_ip, addresses)) then 'STATIC'
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
