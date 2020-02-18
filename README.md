# Kubernetes

Operations deployment to Kubernetes

## Installasjon

```
istioctl manifest apply \
  --set values.kiali.enabled=true \
  --set values.global.mtls.enabled=true \
  --set values.global.controlPlaneSecurityEnabled=true
kubectl apply -Rf .
```
