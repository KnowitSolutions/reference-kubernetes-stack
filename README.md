# Kubernetes

Operations deployment to Kubernetes

## Installation

```
istioctl manifest apply \
  --set values.global.mtls.enabled=true \
  --set values.global.controlPlaneSecurityEnabled=true \
  --set values.sidecarInjectorWebhook.rewriteAppHTTPProbe=true
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
kubectl --namespace db expose deployment cassandra --port 9042
```
