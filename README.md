# Kubernetes

Operations deployment to Kubernetes

## Installation

```
istioctl manifest apply \
  --set values.security.enabled=true \
  --set values.sidecarInjectorWebhook.rewriteAppHTTPProbe=true \
  --set values.prometheus.replicaCount=2 \
  --set values.prometheus.retention=30d \
  --set values.global.tracer.zipkin.address=jaeger-collector.monitoring:9411 \
  --set values.pilot.traceSampling=100
```

Note: rewriteAppHTTPProbe seems to be unnecessary after Istio v1.6.
Note: security.enabled is just a workaround for [this bug](https://github.com/istio/istio/issues/22391).

## Development
```
kubectl create ns db
kubectl label ns db istio-injection=enabled

kubectl --namespace db create deployment postgres --image=postgres
kubectl --namespace db set env deployment postgres POSTGRES_DB=keycloak POSTGRES_PASSWORD=postgres
kubectl --namespace db expose deployment postgres --cluster-ip=None --port 5432

kubectl --namespace db create deployment cassandra --image=cassandra
kubectl --namespace db set env deployment cassandra CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch
kubectl --namespace db expose deployment cassandra --cluster-ip=None --port 9042

jsonnet \
  --tla-str cassandra_address='cassandra.db' \
  --tla-str postgres_address='postgres.db' \
  --tla-str postgres_username='postgres' \
  --tla-str postgres_password='postgres' \
  --tla-str keycloak_address='keycloak.localhost' \
  --tla-str grafana_address='grafana.localhost' \
  --tla-str kiali_address='kiali.localhost' \
  --tla-str jaeger_address='jaeger.localhost' \
  --yaml-stream \
  main.jsonnet | kubectl apply --filename -
```
