local metadata = import 'metadata.jsonnet';

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

  httpSolver():: {
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
