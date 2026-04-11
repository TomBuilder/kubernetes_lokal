# Runbook: Lokales Setup fuer Anwendung A

## Ziel

Dieses Runbook beschreibt den ersten lokalen Aufbau fuer das Lernen von Kubernetes, vCluster, Helm und lokalem Ingress.

## Schritte

1. Host-Cluster mit `kind` erstellen.
2. `metrics-server` im Host-Cluster installieren.
3. `ingress-nginx` im Host-Cluster installieren.
4. Das echte Worker-Image in `kind` laden.
5. `vCluster` fuer Anwendung A anlegen.
6. In den vCluster verbinden.
7. DB-Secret fuer den Worker anlegen.
8. Testeranwendungen deployen.
9. Pods, Ingress, Worker-Logs und Host-Metriken pruefen.

## Befehle

```powershell
kind create cluster --config .\local\kind\cluster-config.yaml

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml --context kind-host-cluster
kubectl patch deployment metrics-server -n kube-system --context kind-host-cluster --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl rollout status deployment/metrics-server -n kube-system --context kind-host-cluster --timeout=120s

helm upgrade --install ingress-nginx ingress-nginx `
  --repo https://kubernetes.github.io/ingress-nginx `
  --namespace ingress-nginx `
  --create-namespace `
  -f .\local\ingress\ingress-nginx-values.yaml

kubectl wait --namespace ingress-nginx `
  --for=condition=ready pod `
  --selector=app.kubernetes.io/component=controller `
  --timeout=120s

kind load docker-image conregipsentw.azurecr.io/zvd-priorisierung:2.0.0.25447 --name host-cluster

vcluster create app-a --namespace vcluster-app-a --connect=false -f .\local\vcluster\vcluster-values.yaml
vcluster connect app-a --namespace vcluster-app-a

kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster create secret generic app-a-worker-db `
  --from-literal=imageCenterRepository='Host=host.docker.internal;Port=5433;Database=ZVD;Username=postgres;Password=IP79199pb;' `
  --from-literal=imageCenterSettingsContext='Host=host.docker.internal;Port=5433;Database=ZVD;Username=postgres;Password=IP79199pb;' `
  --from-literal=postgresPassword='IP79199pb;' `
  -n default

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

## Lokale Besonderheiten

- `D:\Testumgebung\ZVD` wird ueber `local/kind/cluster-config.yaml` per `extraMounts` in den `kind`-Node nach `/var/local/app-a-runtime/zvd` eingebunden.
- Die Worker nutzen lokal `hostPath` statt PVC fuer ihre Laufzeitdaten.
- `tester1` sieht dadurch `D:\Testumgebung\ZVD\tester1` im Container als `/configdata`.
- `tester2` sieht dadurch `D:\Testumgebung\ZVD\tester2` im Container als `/configdata`.
- Die Steuerung der fachlichen Umgebung erfolgt zusaetzlich pro Release ueber `ServiceConfiguration__InstallationEnvironment` mit `tester1` bzw. `tester2`.
- Nach Aenderungen an `local/kind/cluster-config.yaml` muss der `kind`-Cluster neu erstellt werden, weil `extraMounts` nicht nachtraeglich uebernommen werden.

## Wichtige Pruefbefehle

```powershell
kubectl get pods -A
helm list -A
kubectl --context kind-host-cluster get ingress -A
kubectl top nodes --context kind-host-cluster
kubectl top pods -n vcluster-app-a --context kind-host-cluster
kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster get secret app-a-worker-db -n default
kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster logs deploy/tester1-app-a-worker -n default --tail=50
kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster logs deploy/tester2-app-a-worker -n default --tail=50
```

## KEDA lokal ausprobieren

Voraussetzung:

- KEDA ist im Cluster installiert.
- Die SQL-Abfrage in `local/sample-values/tester1-values.yaml` oder `local/sample-values/tester2-values.yaml` passt zur realen Tabelle.

Der aktuelle lokale Trigger basiert auf PostgreSQL und zaehlt Eintraege in `REPO.TASKS` mit:

- `WORKFLOWID = 'ZAHLVERD'`
- `WORKFLOWSTATE = 99`
- `WORKFLOWQUEUE = 'Ready'`
- `ISDELETED = 0`
- `INDEX2 = '0800'` fuer `tester1`
- `INDEX2 = '0801'` fuer `tester2`
- die Verbindung wird fuer KEDA explizit ueber `host`, `port`, `dbName`, `userName` und eine `TriggerAuthentication` aus Secret aufgebaut
- lokal wird `sslmode = disable` verwendet

Fuer den ersten lokalen Test ist `maxReplicaCount` bewusst auf `1` gesetzt, damit nur zwischen `0` und `1` Worker skaliert wird.

Zum Aktivieren fuer `tester1`:

```powershell
helm upgrade --install tester1 .\helm\app-a `
  -n default `
  -f .\helm\app-a\values-local.yaml `
  -f .\local\sample-values\tester1-values.yaml `
  -f .\local\sample-values\tester1-branding.yaml `
  --set worker.keda.enabled=true `
  --set worker.replicaCount=0 `
  --kube-context vcluster_app-a_vcluster-app-a_kind-host-cluster
```

Pruefen:

```powershell
kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster get scaledobject -n default
kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster describe scaledobject tester1-app-a-worker -n default
kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster get deployment tester1-app-a-worker -n default
kubectl --context vcluster_app-a_vcluster-app-a_kind-host-cluster get hpa -n default
```

Wenn die DB-Abfrage `0` liefert, darf der Worker auf `0` gehen. Sobald die Abfrage `>= 1` liefert, sollte KEDA den Worker wieder aktivieren.

## Erwartetes Ergebnis

- Ein laufender Host-Cluster
- Ein laufender `metrics-server` im Host-Cluster
- Ein laufender `ingress-nginx` Controller im Host-Cluster
- Ein laufender `vCluster`
- Zwei deployte Testerinstanzen im `vCluster`
- Zwei laufende Worker-Deployments im `vCluster`
- Ein vorhandenes Secret `app-a-worker-db` im `vCluster`
- Je Tester ein aus dem `vCluster` in den Host-Cluster synchronisierter Ingress
- Host-Metriken in Lens und per `kubectl top`
- Laufzeitdateien und Logs unter `D:\Testumgebung\ZVD\tester1` und `D:\Testumgebung\ZVD\tester2`

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

Zusaetzlich sollten die Worker in den Logs die jeweils gesetzte Umgebung und die initiale Konfiguration zeigen:

```text
tester1 -> ServiceConfiguration__InstallationEnvironment=tester1
tester2 -> ServiceConfiguration__InstallationEnvironment=tester2
```

## Mehrere Tester im selben vCluster

Fuer mehrere Tester wird kein weiterer `vCluster` erzeugt. Stattdessen bekommt jeder Tester:

- ein eigenes Helm-Release
- einen eigenen Ingress-Host
- eine eigene Host-Pfad-Unterstruktur unter `D:\Testumgebung\ZVD`
- eigene Worker-Env-Vars ueber `local/sample-values/<tester>-values.yaml`

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
helm list -n default --kube-context vcluster_app-a_vcluster-app-a_kind-host-cluster
```

Die Beispiel-Overlays fuer weitere Tester liegen in `local/sample-values/`.
