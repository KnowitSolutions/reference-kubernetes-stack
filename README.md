# Kubernetes

Operations deployment to Kubernetes

## Installation

```
istioctl manifest apply \
  --set values.global.mtls.enabled=true \
  --set values.global.controlPlaneSecurityEnabled=true \
  --set values.sidecarInjectorWebhook.rewriteAppHTTPProbe=true \
  --set values.prometheus.replicaCount=2 \
  --set values.prometheus.retention=30d \
  --set values.global.tracer.zipkin.address=jaeger-collector.monitoring:9411 \
  --set values.pilot.traceSampling=100
```

```
jsonnet --yaml-stream main.jsonnet | kubectl apply --filename -
```

## Local environment
```
kubectl create ns db
kubectl label ns db istio-injection=enabled

kubectl --namespace db create deployment postgres --image=postgres
kubectl --namespace db set env deployment postgres POSTGRES_PASSWORD=postgres
kubectl --namespace db expose deployment postgres --port 5432

kubectl --namespace db create deployment cassandra --image=cassandra
kubectl --namespace db set env deployment cassandra CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch
kubectl --namespace db expose deployment cassandra --port 9042
```
