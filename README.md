# Kubernetes

Operations deployment to Kubernetes

## Local environment
```
kubectl create ns db
kubectl label ns db istio-injection=enabled
kubectl --namespace db create deployment postgres --image=postgres
kubectl --namespace db set env deployment postgres POSTGRES_PASSWORD=postgres
kubectl --namespace db expose deployment postgres --port 5432
```

## Installation

```
istioctl manifest apply \
  --set values.global.mtls.enabled=true \  # TODO: Check if this is needed when using istio-injection=enabled
  --set values.global.controlPlaneSecurityEnabled=true \
  --set values.sidecarInjectorWebhook.rewriteAppHTTPProbe=true
```

```
jsonnet --yaml-stream main.jsonnet | kubectl apply --filename -
```
