local metadata = import 'metadata.jsonnet';

{
  new()::
    {
      apiVersion: 'v1',
      kind: 'Namespace',
    } +
    metadata.label('istio-injection', 'enabled'),
}
