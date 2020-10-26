local metadata = import 'metadata.jsonnet';

{
  new(commonName, issuer='lets-encrypt'):: {
    apiVersion: 'cert-manager.io/v1alpha2',
    kind: 'Certificate',
    spec: {
      issuerRef: {
        name: issuer,
      },
      secretName: commonName,
      commonName: commonName,
      dnsNames: [
        commonName,
      ],
    },
  } + metadata.new(commonName, ns='istio-system'),
}
