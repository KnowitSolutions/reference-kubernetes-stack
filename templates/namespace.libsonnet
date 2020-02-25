local metadata = import 'metadata.libsonnet';

{
  new()::
    {
      apiVersion: 'v1',
      kind: 'Namespace',
    } +
    metadata.label('istio-injection', 'enabled'),
}
