# Runbook: Lokales Setup fuer Anwendung A

## Ziel

Dieses Runbook beschreibt den ersten lokalen Aufbau fuer das Lernen von Kubernetes, vCluster und Helm.

## Schritte

1. Host-Cluster mit `kind` erstellen.
2. `vCluster` fuer Anwendung A anlegen.
3. In den vCluster verbinden.
4. Helm-Chart deployen.
5. Pods, Service und PVC pruefen.

## Wichtige Pruefbefehle

```powershell
kubectl get pods -A
kubectl get pvc -A
kubectl get svc -A
helm list -A
```

## Erwartetes Ergebnis

- Ein laufender Host-Cluster
- Ein laufender `vCluster`
- Eine deployte Beispielanwendung in `vCluster app-a`
- Ein gebundener PVC fuer persistenten Speicher
