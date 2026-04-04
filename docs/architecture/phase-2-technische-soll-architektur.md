# Phase 2: Technische Soll-Architektur und Umsetzungsstruktur fuer Anwendung A

## Ziel dieser Phase

Diese Phase uebersetzt die Zielarchitektur in konkrete technische Bausteine, die als Grundlage fuer das lokale Lernen, spaeteres Terraform und das Deployment auf AKS dienen.

Am Ende dieser Phase soll klar sein:

- wie das Repository strukturiert wird
- welche Verantwortung Terraform uebernimmt
- welche Verantwortung Helm uebernimmt
- wie das lokale Lern-Setup aussieht
- wie Secrets, Storage und Zugriffe gedacht sind

## Empfohlene Repository-Struktur

```text
kubernetes_lokal/
  docs/
    architecture/
      zielarchitektur-anwendung-a.md
      phase-2-technische-soll-architektur.md
    decisions/
    runbooks/
  local/
    kind/
    vcluster/
    sample-values/
  helm/
    app-a/
      Chart.yaml
      values.yaml
      templates/
    platform/
  terraform/
    modules/
      aks/
      identity/
      keyvault-integration/
      storage/
    environments/
      shared/
      platform-test/
      app-a-state/
```

## Verantwortungstrennung

### Terraform

Terraform ist fuer Infrastruktur und Azure-Integration zustaendig.

Dazu gehoeren:

- AKS und clusternahe Infrastruktur
- Managed Identity oder Workload Identity
- Storage fuer Anwendung A
- Key-Vault-Anbindung
- optionale Referenzierung bestehender Shared-Ressourcen
- Netzwerk- und Zugriffsanbindung, soweit noetig

Nicht Teil von Terraform in dieser Phase:

- das eigentliche Deployment der Anwendung
- laufende Releases der Anwendung im vCluster

### Helm

Helm ist fuer das Deployment und die Konfiguration der Anwendung im vCluster zustaendig.

Dazu gehoeren:

- Deployment oder StatefulSet
- Service
- Ingress
- PVC-Nutzung
- Secret-Referenzen
- Image-Konfiguration fuer ACR
- mandantenbezogene Applikationswerte

## Terraform-Layer

Die Schichten sollten bewusst getrennt werden, damit Plattform, State und Shared-Dienste sauber voneinander getrennt bleiben.

### 1. Shared Layer

Zweck:

- bestehende gemeinsam genutzte Ressourcen dokumentieren oder referenzieren

Typische Inhalte:

- Azure Container Registry
- Key Vault
- DNS-Zonen oder Zertifikatsressourcen

Empfohlener Ordner:

- `terraform/environments/shared`

### 2. Platform Layer

Zweck:

- AKS und gemeinsame Plattformdienste bereitstellen

Typische Inhalte:

- AKS
- zentrale Identities
- Log Analytics
- Monitoring-nahe Konfiguration
- spaetere Voraussetzungen fuer Ingress und Secret-Mechanismen

Empfohlener Ordner:

- `terraform/environments/platform-test`

### 3. App State Layer

Zweck:

- externe zustandsbehaftete Ressourcen fuer Anwendung A getrennt verwalten

Typische Inhalte:

- Storage Account
- Fileshare oder andere Speicherressourcen
- optionale Backupeinstellungen
- Referenz auf bestehenden PostgreSQL Flexible Server als Input, nicht als neue Ressource

Empfohlener Ordner:

- `terraform/environments/app-a-state`

## Helm-Struktur fuer Anwendung A

Empfohlener Start fuer `helm/app-a`:

- `Chart.yaml`
- `values.yaml`
- `values-local.yaml`
- `values-aks.yaml`
- `templates/deployment.yaml` oder `templates/statefulset.yaml`
- `templates/service.yaml`
- `templates/ingress.yaml`
- `templates/pvc.yaml`
- `templates/secret-ref.yaml` falls noetig

### Wichtige Values

Das Chart sollte frueh eine saubere Struktur fuer folgende Werte haben:

- `image.repository`
- `image.tag`
- `image.pullSecrets`
- `app.database.secretName`
- `app.database.connectionStringKey`
- `app.storage.enabled`
- `app.storage.size`
- `app.storage.storageClassName`
- `ingress.enabled`
- `ingress.hosts`
- `tenant.*` fuer mandantenbezogene Konfiguration

Wichtig:

- keine echten Zugangsdaten in `values.yaml`
- Secrets nur ueber Referenzen einbinden

## Secret-Modell

Da der PostgreSQL Flexible Server bereits existiert und per Connection String angebunden wird, sollte dieser Connection String extern verwaltet werden.

Empfohlene Zielrichtung:

- Connection String liegt in `Azure Key Vault`
- Im Cluster wird daraus ein Kubernetes Secret erzeugt oder gemountet
- Helm referenziert nur den Namen dieses Secrets

### Entscheidungsvorlage

Es gibt zwei sinnvolle Optionen:

1. `External Secrets Operator`
   Gut, wenn Kubernetes-Secrets aktiv aus externen Secrets synchronisiert werden sollen.

2. `Secrets Store CSI Driver`
   Gut, wenn Secrets eher als Volumes oder ueber integrierte Azure-Anbindung eingebracht werden.

Vorlaeufige Empfehlung:

- `External Secrets Operator`, weil das fuer Helm und klassische App-Konfiguration haeufig sehr angenehm ist

## Storage-Modell

Die Anwendung benoetigt persistenten externen Speicher. Da dieser ausserhalb der AKS-Resource-Group liegen soll, wird er als eigene Azure-Ressource verwaltet.

Vorlaeufige technische Richtung:

- `Azure Files` als Startpunkt
- Einbindung im Cluster ueber passende CSI-Unterstuetzung
- Nutzung in der Anwendung ueber PVC

### Warum diese Richtung sinnvoll ist

- geeignet fuer dauerhafte Testumgebungen
- einfaches Zusammenspiel mit Kubernetes-Persistenz
- flexibler als podlokaler ephemerer Speicher

Offen bleibt noch:

- ob wirklich Shared-File-Semantik benoetigt wird
- ob Performance oder Locking-Verhalten besondere Anforderungen haben

## Zugriffsmodell fuer Tester

Der Tester soll sein Deployment eigenstaendig steuern, aber keine Plattformdienste veraendern.

Empfohlene Richtung:

- Plattformteam verwaltet Host-Cluster und Plattformkomponenten
- Tester oder Anwendungsteam erhalten Zugriff auf den vCluster
- Deployments erfolgen im vCluster per `helm upgrade --install`
- spaeter kann das in CI/CD ueberfuehrt werden

### Praktische Varianten

Variante A:

- direkter `kubectl`- und `helm`-Zugriff auf den vCluster

Variante B:

- Deployment nur ueber Pipeline oder Skript

Vorlaeufige Empfehlung fuer Lernen und Pilot:

- Variante A, weil sie das Verhalten transparent macht und schnelleres Lernen ermoeglicht

## Grafische Verwaltung

Fuer den Pilot ist eine leichte Oberflaeche sinnvoll.

Empfehlung:

- `Headlamp` als Weboberflaeche
- optional `Lens` fuer Admins oder tiefere technische Einsicht

Ziel ist nicht Vollautomatisierung, sondern Sichtbarkeit und einfache Bedienbarkeit.

## Lokales Start-Setup

Das lokale Setup soll die Architektur logisch nachbilden, nicht Azure exakt emulieren.

### Lokale Werkzeuge

- `kind`
- `kubectl`
- `helm`
- `vcluster`
- optional `k9s`

### Lokale Schritte

1. `kind`-Cluster als Host-Cluster erstellen.
2. Einen `vCluster` fuer Anwendung A anlegen.
3. Eine Beispielanwendung per Helm in den vCluster deployen.
4. Persistenz lokal ueber PVC abbilden.
5. DB-Verbindungsdaten lokal ueber Dummy-Secret simulieren.
6. Spaeter AKS-spezifische Integration fuer ACR, Key Vault und Azure Files nachziehen.

## Deployment-Ablauf als Zielmodell

Der spaetere Zielablauf sollte in etwa so aussehen:

1. Image wird in `ACR` bereitgestellt.
2. Tester waehlt Version oder Tag.
3. Helm-Release wird im vCluster aktualisiert.
4. Anwendung liest DB-Connection-String aus Secret.
5. Anwendung nutzt persistenten Speicher ueber PVC.
6. Tester validiert das Verhalten in der dauerhaften Umgebung.

## Offene Punkte fuer die naechste Ausarbeitung

Diese Punkte sollten wir als naechstes konkret entscheiden oder dokumentieren:

- `Deployment` oder `StatefulSet` fuer Anwendung A
- exakte Storage-Anforderung der Anwendung
- Secret-Mechanismus final festlegen
- Hostname- und Ingress-Modell fuer die Testumgebung
- RBAC-Modell fuer Tester im vCluster
- spaetere CI/CD-Integration

## Nächster sinnvoller Schritt

Nach dieser Phase sollte als Nächstes ein lokales Grundgerüst angelegt werden:

- Verzeichnisse fuer `local`, `helm` und `terraform`
- erste Dokumentation fuer das lokale Setup
- erstes minimales Helm-Chart fuer Anwendung A
- erste Entscheidungsnotiz fuer Secret- und Storage-Modell
