{
  new(labels=null):: {
    apiVersion: 'security.istio.io/v1beta1',
    kind: 'PeerAuthentication',
    spec: {
      [if labels != null then 'selector']: { matchLabels: labels },
    },
  },

  mtls(mtls, port=null):: {
    local mode = { mode: if mtls then 'STRICT' else 'DISABLE' },
    spec+: {
      [if port == null then 'mtls']: mode,
      [if port != null then 'portLevelMtls']: { [std.toString(port)]: mode },
    },
  },
}
