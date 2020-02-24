# Kubernetes

Operations deployment to Kubernetes

## Installasjon

```
istioctl manifest apply \
  --set values.global.mtls.enabled=true \
  --set values.global.controlPlaneSecurityEnabled=true \
  --set values.sidecarInjectorWebhook.rewriteAppHTTPProbe=true \
  --set values.kiali.enabled=true
kubectl apply -Rf .
```
