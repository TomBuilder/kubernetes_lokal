# Lokales Setup

Dieses Verzeichnis enthaelt das lokale Lern- und Test-Setup fuer Anwendung A.

## Ziel

Lokal wird ein Host-Cluster mit `kind` aufgebaut. Darin laeuft ein dauerhafter `vCluster` fuer Anwendung A. Die Anwendung wird per Helm in den vCluster ausgerollt und ueber einen Ingress im Host-Cluster erreichbar gemacht.

## Voraussetzungen

- `kind`
- `kubectl`
- `helm`
- `vcluster`
- `docker`
- `.NET SDK`, wenn das Worker-Image lokal neu gebaut werden soll
- Internetzugriff fuer `ingress-nginx` und `metrics-server`

## 1. Host-Cluster erstellen

```powershell
kind create cluster --config .\local\kind\cluster-config.yaml
```

## 2. Metrics Server im Host-Cluster installieren

Fuer Host-Metriken in Lens und `kubectl top` wird im lokalen `kind`-Cluster ein `metrics-server` benoetigt.

```powershell
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml --context kind-host-cluster
kubectl patch deployment metrics-server -n kube-system --context kind-host-cluster `
  --type=json `
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl rollout status deployment/metrics-server -n kube-system --context kind-host-cluster --timeout=120s
```

Der Patch mit `--kubelet-insecure-tls` ist fuer den lokalen `kind`-Cluster noetig, damit `kubectl top` und Lens-Metriken funktionieren.

## 3. Ingress Controller im Host-Cluster installieren

Der lokale Ingress laeuft im Host-Cluster. Die Anwendung erzeugt ihren Ingress im `vCluster`, der dann in den Host-Cluster synchronisiert wird.

```powershell
helm upgrade --install ingress-nginx ingress-nginx `
  --repo https://kubernetes.github.io/ingress-nginx `
  --namespace ingress-nginx `
  --create-namespace `
  -f .\local\ingress\ingress-nginx-values.yaml

kubectl wait --namespace ingress-nginx `
  --for=condition=ready pod `
  --selector=app.kubernetes.io/component=controller `
  --timeout=120s
```

## 4. Worker-Images lokal bauen und in kind laden

Der Background Worker wird lokal als Docker-Image gebaut und anschliessend in den `kind`-Cluster geladen.

```powershell
docker build -t app-a-worker:1.1.0 -t app-a-worker:2.0.0 -f .\src\AppA.Worker\Dockerfile .
kind load docker-image app-a-worker:1.1.0 app-a-worker:2.0.0 --name host-cluster
```

## 5. vCluster erstellen

```powershell
vcluster create app-a --namespace vcluster-app-a --connect=false -f .\local\vcluster\vcluster-values.yaml
```

## 6. Mit dem vCluster verbinden

```powershell
vcluster connect app-a --namespace vcluster-app-a
```

## 7. Testeranwendungen deployen

```powershell
helm upgrade --install tester1 .\helm\app-a `
  -n default `
  -f .\helm\app-a\values-local.yaml `
  -f .\local\sample-values\tester1-values.yaml `
  -f .\local\sample-values\tester1-branding.yaml `
  --kube-context vcluster_app-a_vcluster-app-a_kind-host-cluster

helm upgrade --install tester2 .\helm\app-a `
  -n default `
  -f .\helm\app-a\values-local.yaml `
  -f .\local\sample-values\tester2-values.yaml `
  -f .\local\sample-values\tester2-branding.yaml `
  --kube-context vcluster_app-a_vcluster-app-a_kind-host-cluster
```

## 8. Zugriff testen

Die Tester-Instanzen verwenden lokal eigene Hostnamen.

Trage dafuer einmalig Host-Eintraege ein:

```text
127.0.0.1 tester1.app-a.local
127.0.0.1 tester2.app-a.local
```

Danach sollten die Anwendungen ueber den Ingress erreichbar sein:

```text
http://tester1.app-a.local:8080/
http://tester2.app-a.local:8080/
```

Die Worker-Version ist auf der Seite sichtbar. Die Worker-Logs selbst kannst du so pruefen:

```powershell
kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster logs deploy/tester1-app-a-worker -n default --tail=10
kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster logs deploy/tester2-app-a-worker -n default --tail=10
```

Host-Metriken pruefen:

```powershell
kubectl top nodes --context kind-host-cluster
kubectl top pods -n vcluster-app-a --context kind-host-cluster
```

Zum Debuggen ist es oft hilfreich, den synchronisierten Ingress im Host-Cluster explizit anzusehen:

```powershell
kubectl --context kind-host-cluster get ingress -A
```

## 9. Weitere Tester im selben vCluster anlegen

Jeder weitere Tester bekommt ein eigenes Helm-Release und einen eigenen Hostnamen. Die Trennung erfolgt ueber den Release-Namen und nicht ueber einen weiteren `vCluster`.

Beispiel:

```powershell
helm upgrade --install tester1 .\helm\app-a `
  -n default `
  -f .\helm\app-a\values-local.yaml `
  -f .\local\sample-values\tester1-values.yaml `
  -f .\local\sample-values\tester1-branding.yaml `
  --kube-context vcluster_app-a_vcluster-app-a_kind-host-cluster
```

Fuer den lokalen Browserzugriff ist zusaetzlich ein Host-Eintrag noetig:

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

## Hinweise

- Der lokale Betrieb verwendet Dummy-Werte fuer Datenbank und Storage.
- ACR, Key Vault und Azure Files werden erst in den naechsten Phasen angebunden.
- Das Chart ist absichtlich minimal gehalten, damit die Grundprinzipien klar bleiben.
- Die Port-Mappings `8080` und `8443` aus `kind` werden auf die NodePorts `30080` und `30443` des Ingress Controllers geleitet.
- Beispiel-Overlays fuer weitere Tester liegen in `local/sample-values/`.
