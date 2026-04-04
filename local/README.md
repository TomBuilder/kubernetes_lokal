# Lokales Setup

Dieses Verzeichnis enthaelt das lokale Lern- und Test-Setup fuer Anwendung A.

## Ziel

Lokal wird ein Host-Cluster mit `kind` aufgebaut. Darin laeuft ein dauerhafter `vCluster` fuer Anwendung A. Die Anwendung wird per Helm in den vCluster ausgerollt.

## Voraussetzungen

- `kind`
- `kubectl`
- `helm`
- `vcluster`

## 1. Host-Cluster erstellen

```powershell
kind create cluster --config .\local\kind\cluster-config.yaml
```

## 2. vCluster erstellen

```powershell
vcluster create app-a --namespace vcluster-app-a --connect=false -f .\local\vcluster\vcluster-values.yaml
```

## 3. Mit dem vCluster verbinden

```powershell
vcluster connect app-a --namespace vcluster-app-a
```

## 4. Beispielanwendung deployen

```powershell
helm upgrade --install app-a .\helm\app-a -f .\helm\app-a\values-local.yaml
```

## Hinweise

- Der lokale Betrieb verwendet Dummy-Werte fuer Datenbank und Storage.
- ACR, Key Vault und Azure Files werden erst in den naechsten Phasen angebunden.
- Das Chart ist absichtlich minimal gehalten, damit die Grundprinzipien klar bleiben.
