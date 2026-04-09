# Lokales Setup

Dieses Verzeichnis enthaelt das lokale Lern- und Test-Setup fuer Anwendung A.

## Ziel

Lokal wird ein Host-Cluster mit `kind` aufgebaut. Darin laeuft ein dauerhafter `vCluster` fuer Anwendung A. Die Anwendung wird per Helm in den vCluster ausgerollt und ueber einen Ingress im Host-Cluster erreichbar gemacht.

## Voraussetzungen

- `kind`
- `kubectl`
- `helm`
- `vcluster`

## 1. Host-Cluster erstellen

```powershell
kind create cluster --config .\local\kind\cluster-config.yaml
```

## 2. Ingress Controller im Host-Cluster installieren

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

## 3. vCluster erstellen

```powershell
vcluster create app-a --namespace vcluster-app-a --connect=false -f .\local\vcluster\vcluster-values.yaml
```

## 4. Mit dem vCluster verbinden

```powershell
vcluster connect app-a --namespace vcluster-app-a
```

## 5. Beispielanwendung deployen

```powershell
helm upgrade --install app-a .\helm\app-a -f .\helm\app-a\values-local.yaml
```

## 6. Zugriff testen

Das Chart aktiviert lokal einen Ingress mit dem Hostnamen `app-a.local`.

Trage dafuer einmalig einen Host-Eintrag ein:

```text
127.0.0.1 app-a.local
```

Danach sollte die Anwendung ueber den Ingress erreichbar sein:

```text
http://app-a.local:8080/
```

Zum Debuggen ist es oft hilfreich, den synchronisierten Ingress im Host-Cluster explizit anzusehen:

```powershell
kubectl --context kind-host-cluster get ingress -A
```

## Hinweise

- Der lokale Betrieb verwendet Dummy-Werte fuer Datenbank und Storage.
- ACR, Key Vault und Azure Files werden erst in den naechsten Phasen angebunden.
- Das Chart ist absichtlich minimal gehalten, damit die Grundprinzipien klar bleiben.
- Die Port-Mappings `8080` und `8443` aus `kind` werden auf die NodePorts `30080` und `30443` des Ingress Controllers geleitet.
