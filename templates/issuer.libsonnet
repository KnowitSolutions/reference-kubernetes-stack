local metadata = import 'metadata.libsonnet';

{
  new(email):: {
    local issuer = self,
    apiVersion: 'cert-manager.io/v1alpha2',
    kind: 'Issuer',
    spec: {
      acme: {
        server: 'https://acme-v02.api.letsencrypt.org/directory',
        email: email,
        privateKeySecretRef: {
          name: issuer.metadata.name,
        },
      },
    },
  } + metadata.new('lets-encrypt', 'istio-system'),

  http_solver():: {
    spec+: {
      acme+: {
        solvers+: [
          {
            http01: {
              ingress: {
                class: 'istio',
              },
            },
          },
        ],
      },
    },
  },
}
