# Reference Kubernetes stack

At Knowit we love Kubernetes. We love deploying straight into prodction. We love containers and all the great tings they bring. But we spent a lot of time building the competence and experience to operate such an environment, and a lot more time discovering and adapting a number of quality-of-life features.

We are open sourcing this reference stack because we needed to create something like this in order to be comfortable operating on Kubernetes. Chances are, you are going to have the same experience and perhaps might want to not spend a lot of effort solving each problem yourself.

This stack was designed specifically in order to provide our cloud solutions with a solid framework for general services such as authentication, and a strong set of tools to make our Kubernetes environment robust and easy to operate and support.

This project serves as the reference implementation for auxiliary services used in projects by Knowit Reaktor Solutions AS running on Kubernetes. It provides tools and utilities for better visibility into what is going on inside your cluster to help debugging and finding problems with your deployments, and can also easily be extended to track new metrics. The stack builds on top of Istio which provides service meshing. The following coponents are provided:

* Service meshing with Istio
* Service mesh observability and tracing with Kiali and Jaeger
* Metrics collection with Prometheus
* Log collection and aggregation by Promtail and Loki
* Metrics and logs visualization and dashboards through Grafana
* Single sign-on services provided by Keycloak

## Installation

### Dependencies

To run subsequent commands `istioctl` and `jsonnet` has to be installed. Both projects supply pre-built binaries for Linux, and are available through Homebrew for macOS. Windows users are encouraged to use Windows Subsystem for Linux and proceed as if on Linux. Instructions for installing can be found in the links below.

* [Istio](https://istio.io/docs/setup/getting-started/)
* [Jsonnet](https://github.com/google/jsonnet/releases)

### Istio

The stack is build and tested against version 1.6.0 of Istio. Newer versions might work, but the stack is incompatible with older versions.
The command given below installs Istio if it is not already installed, or resets Istio's configuration to the provided values. These configurations are neccecary for the stack to function properly.

```
istioctl install \
  --set values.global.tracer.zipkin.address=jaeger-collector.base:9411 \
  --set values.pilot.traceSampling=100
```

Support for provisioning TLS certificates for use with HTTPS is provided through Cert manager. To use this functionality Cert manager must first be installed as described [here](https://cert-manager.io/docs/installation/kubernetes/).

### Local development databases

For local development the required Postgres database can run as a Kubernetes deployment. This will however not provide any persistence, and as such all data in the database is lost every time the associated pod is restarted. The following commands will setup a namespace `db` and create the database inside it.

```
kubectl --namespace=default run postgres --image=postgres --env=POSTGRES_PASSWORD=postgres --port=5432
kubectl --namespace=default expose pod postgres
until kubectl --namespace=default exec postgres -- gosu postgres psql &> /dev/null; do done
kubectl --namespace=default exec postgres -- gosu postgres psql --command 'CREATE DATABASE keycloak'
kubectl --namespace=default exec postgres -- gosu postgres psql --command 'CREATE DATABASE grafana'
```

### Reference stack

All the components in the reference stack are configured with [Jsonnet](https://jsonnet.org) and dependencies are managed by [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler) (`jb`).

First download the required dependencies:

```
jb install
```

Afterwards Kubernetes manifests can be generated by executing Jsonnet on `main.jsonnet`. Some additional configurations like database connection details and external hostnames must also be supplied with the `--tla-str <option>=<value>` flag. An extensive list of these options and their default values can be seen inside the `main.jsonnet` file. The generated manifests can be piped directly to `kubectl apply` to deploy to Kubernetes.

```
jsonnet <configuration-flags> --jpath vendor --yaml-stream main.jsonnet | kubectl apply --filename -
```

For local development installations the following command should be a good starting point:

```
jsonnet \
  --tla-code CASSANDRA_REPLICAS=1 \
  --tla-str POSTGRES_ADDRESS='postgres.default' \
  --tla-str POSTGRES_USERNAME='postgres' \
  --tla-str POSTGRES_PASSWORD='postgres' \
  --tla-code PROMETHEUS_REPLICAS=1 \
  --tla-code LOKI_REPLICAS=1 \
  --tla-code KEYCLOAK_REPLICAS=1 \
  --tla-str KEYCLOAK_ADDRESS='keycloak.localhost' \
  --tla-code ISTIO_OIDC_REPLICAS=1 \
  --tla-code GRAFANA_REPLICAS=1 \
  --tla-str GRAFANA_ADDRESS='grafana.localhost' \
  --tla-code KIALI_REPLICAS=1 \
  --tla-str KIALI_ADDRESS='kiali.localhost' \
  --tla-code JAEGER_REPLICAS=1 \
  --tla-str JAEGER_ADDRESS='jaeger.localhost' \
  --jpath vendor \
  --yaml-stream \
  main.jsonnet | kubectl apply --filename -
```
