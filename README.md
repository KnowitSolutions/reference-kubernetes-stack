# Reference Kubernetes stack

We love Kubernetes. We love deploying straight into prodction. We love containers and all the great tings they bring. But we spent a lot of time building the competence and experience to operate such an environment, and a lot more time discovering and adapting a number of quality-of-life features. 

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

The stack is build and tested against version 1.5.1 of Istio. Newer versions might work, but the stack is incompatible with older versions.
The command given below installs Istio if it is not already installed, or resets Istio's configuration to the provided values. These configurations are neccecary for the stack to function properly.

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

### Local development databases

For local development the required Postgres and Cassandra databases can run as Kubernetes deployments. This will however not provide any persistence, and as such all data in the database is lost every time the associated pods are restarted. The following commands will setup a namespace `db` in which the databases are set up.

```
kubectl create ns db
kubectl label ns db istio-injection=enabled

kubectl --namespace db create deployment postgres --image=postgres
kubectl --namespace db set env deployment postgres POSTGRES_DB=keycloak POSTGRES_PASSWORD=postgres
kubectl --namespace db expose deployment postgres --cluster-ip=None --port 5432

kubectl --namespace db create deployment cassandra --image=cassandra
kubectl --namespace db set env deployment cassandra CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch
kubectl --namespace db expose deployment cassandra --cluster-ip=None --port 9042
```

### Reference stack

All the components in the reference stack are configured with [Jsonnet](https://jsonnet.org). To generate Kubernetes configurations simply invoke the Jsonnet interpreter with the file `main.jsonnet`. Some additional configurations like database connection details and external hostnames must also be supplied with the `--tla-str <option>=<value>` flag. An extensive list of these options and their default values can be seen inside the `main.jsonnet` file. To generate YAML streams like `kubectl` expects the switch `--yaml-stream` must also be enabled. After generating the configuration it can simply be piped to `kubectl` to install everything in Kubernetes, like so:

```
jsonnet <configuration-flags> --yaml-stream main.jsonnet | kubectl apply --filename -
```

For local development installations the following command should be a good starting point:

```
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
