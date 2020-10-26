local metadata = import 'metadata.jsonnet';

{
  new(common_name, issuer='lets-encrypt'):: {
    apiVersion: 'cert-manager.io/v1alpha2',
    kind: 'Certificate',
    spec: {
      issuerRef: {
        name: issuer,
      },
      secretName: common_name,
      commonName: common_name,
      dnsNames: [
        common_name,
      ],
    },
  } + metadata.new(common_name, ns='istio-system'),
}
