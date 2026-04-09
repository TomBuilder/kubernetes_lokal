# Runbook: Lokales Setup fuer Anwendung A

## Ziel

Dieses Runbook beschreibt den ersten lokalen Aufbau fuer das Lernen von Kubernetes, vCluster, Helm und lokalem Ingress.

## Schritte

1. Host-Cluster mit `kind` erstellen.
2. `ingress-nginx` im Host-Cluster installieren.
3. `vCluster` fuer Anwendung A anlegen.
4. In den vCluster verbinden.
5. Helm-Chart deployen.
6. Pods, Service, PVC und Ingress pruefen.

## Befehle

```powershell
kind create cluster --config .\local\kind\cluster-config.yaml

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
helm upgrade --install app-a .\helm\app-a -f .\helm\app-a\values-local.yaml
```

## Wichtige Pruefbefehle

```powershell
kubectl get pods -A
kubectl get pvc -A
kubectl get svc -A
helm list -A
kubectl --context kind-host-cluster get ingress -A
```

## Erwartetes Ergebnis

- Ein laufender Host-Cluster
- Ein laufender `ingress-nginx` Controller im Host-Cluster
- Ein laufender `vCluster`
- Eine deployte Beispielanwendung in `vCluster app-a`
- Ein gebundener PVC fuer persistenten Speicher
- Ein aus dem `vCluster` in den Host-Cluster synchronisierter Ingress fuer `app-a.local`

## Zugriffstest

Fuer den Browser-Test wird lokal ein Host-Eintrag benoetigt:

```text
127.0.0.1 app-a.local
```

Danach ist der Aufruf ueber den vom `kind`-Cluster gemappten HTTP-Port moeglich:

```text
http://app-a.local:8080/
```
