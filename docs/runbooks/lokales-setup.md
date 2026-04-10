# Runbook: Lokales Setup fuer Anwendung A

## Ziel

Dieses Runbook beschreibt den ersten lokalen Aufbau fuer das Lernen von Kubernetes, vCluster, Helm und lokalem Ingress.

## Schritte

1. Host-Cluster mit `kind` erstellen.
2. Worker-Images lokal bauen und in `kind` laden.
3. `ingress-nginx` im Host-Cluster installieren.
4. `vCluster` fuer Anwendung A anlegen.
5. In den vCluster verbinden.
6. Testeranwendungen deployen.
7. Pods, Service, PVC, Ingress und Worker-Logs pruefen.

## Befehle

```powershell
kind create cluster --config .\local\kind\cluster-config.yaml

docker build -t app-a-worker:1.0.0 -t app-a-worker:2.0.0 -f .\src\AppA.Worker\Dockerfile .
kind load docker-image app-a-worker:1.0.0 app-a-worker:2.0.0 --name host-cluster

helm upgrade --install ingress-nginx ingress-nginx `
  --repo https://kubernetes.github.io/ingress-nginx `
  --namespace ingress-nginx `
  --create-namespace `
  -f .\local\ingress\ingress-nginx-values.yaml

kubectl wait --namespace ingress-nginx `
  --for=condition=ready pod `
  --selector=app.kubernetes.io/component=controller `
  --timeout=120s

vcluster create app-a --namespace vcluster-app-a --connect=false -f .\local\vcluster\vcluster-values.yaml
vcluster connect app-a --namespace vcluster-app-a
helm upgrade --install tester1 .\helm\app-a -n default -f .\helm\app-a\values-local.yaml -f .\local\sample-values\tester1-values.yaml -f .\local\sample-values\tester1-branding.yaml
helm upgrade --install tester2 .\helm\app-a -n default -f .\helm\app-a\values-local.yaml -f .\local\sample-values\tester2-values.yaml -f .\local\sample-values\tester2-branding.yaml
```

## Wichtige Pruefbefehle

```powershell
kubectl get pods -A
kubectl get pvc -A
kubectl get svc -A
helm list -A
kubectl --context kind-host-cluster get ingress -A
kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster logs deploy/tester1-app-a-worker -n default --tail=10
kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster logs deploy/tester2-app-a-worker -n default --tail=10
```

## Erwartetes Ergebnis

- Ein laufender Host-Cluster
- Ein laufender `ingress-nginx` Controller im Host-Cluster
- Ein laufender `vCluster`
- Zwei deployte Testerinstanzen im `vCluster`
- Zwei laufende Worker-Deployments im `vCluster`
- Je Tester ein gebundener PVC
- Je Tester ein aus dem `vCluster` in den Host-Cluster synchronisierter Ingress

## Zugriffstest

Fuer den Browser-Test werden lokal Host-Eintraege benoetigt:

```text
127.0.0.1 tester1.app-a.local
127.0.0.1 tester2.app-a.local
```

Danach sind die Aufrufe ueber den vom `kind`-Cluster gemappten HTTP-Port moeglich:

```text
http://tester1.app-a.local:8080/
http://tester2.app-a.local:8080/
```

Zusätzlich sollten die Worker in den Logs unterschiedliche Versionen ausgeben:

```text
tester1 -> version 1.0.0
tester2 -> version 2.0.0
```

## Mehrere Tester im selben vCluster

Fuer mehrere Tester wird kein weiterer `vCluster` erzeugt. Stattdessen bekommt jeder Tester:

- ein eigenes Helm-Release
- einen eigenen Ingress-Host
- einen eigenen PVC

Beispiel fuer einen weiteren Tester:

```powershell
helm upgrade --install tester1 .\helm\app-a `
  -n default `
  -f .\helm\app-a\values-local.yaml `
  -f .\local\sample-values\tester1-values.yaml `
  -f .\local\sample-values\tester1-branding.yaml `
  --kube-context vcluster_app-a_vcluster-app-a_kind-host-cluster
```

Fuer den lokalen Browserzugriff wird zusaetzlich ein Host-Eintrag benoetigt:

```text
127.0.0.1 tester1.app-a.local
```

Pruefen:

```powershell
kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster get pods
kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster get svc
kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster get ingress
kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster get pvc
helm list -n default --kube-context vcluster_app-a_vcluster-app-a_kind-host-cluster
```

Die Beispiel-Overlays fuer weitere Tester liegen in `local/sample-values/`.
