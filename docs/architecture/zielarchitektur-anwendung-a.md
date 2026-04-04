# Zielarchitektur v1 fuer Anwendung A

## Ziel

Fuer Anwendung A soll eine dauerhafte, von Testern eigenstaendig nutzbare Testumgebung auf Kubernetes entstehen. Die Zielplattform soll lokal lern- und testbar sein und spaeter in Azure Kubernetes Service (AKS) betrieben werden.

Wichtige Randbedingungen:

- Es gibt einen eigenen `vCluster` fuer Anwendung A.
- Die Umgebung ist dauerhaft und wird nicht pro Testlauf neu erzeugt.
- Container-Images werden aus einer Azure Container Registry bezogen.
- Die Anwendung nutzt einen bereits vorhandenen `PostgreSQL Flexible Server`.
- Die Verbindung zur Datenbank erfolgt ueber einen Connection String.
- Die Anwendung benoetigt persistenten externen Speicher.
- Datenbank und Speicher sollen nicht in der Resource Group des AKS-Clusters liegen.
- Der Tester soll Deployments innerhalb seiner Umgebung eigenstaendig steuern koennen.

## Zielbild auf Azure

Die Plattform wird in getrennte Verantwortungs- und Ressourcenschichten aufgeteilt.

### 1. Plattform-Schicht

Diese Schicht enthaelt den AKS-Cluster und die gemeinsamen Cluster-Dienste.

Empfohlene Inhalte:

- AKS-Cluster
- clusternahe Managed Identity oder Workload Identity
- Ingress Controller
- Monitoring und Logging
- Secret-Integration fuer externe Geheimnisse
- vCluster fuer Anwendung A

Empfohlene Resource Group:

- `rg-platform-aks`

### 2. State-Schicht fuer Anwendung A

Diese Schicht enthaelt zustandsbehaftete Ressourcen, die nicht in der Cluster-Resource-Group liegen sollen.

Empfohlene Inhalte:

- bestehender `PostgreSQL Flexible Server` oder dessen logische Einbindung
- persistenter Speicher fuer Anwendung A
- Backup- und Wiederherstellungs-nahe Komponenten

Empfohlene Resource Group:

- `rg-app-a-state`

### 3. Shared-Schicht

Diese Schicht enthaelt gemeinsam genutzte Plattformdienste.

Empfohlene Inhalte:

- Azure Container Registry
- Key Vault
- optional DNS und Zertifikatsdienste

Empfohlene Resource Group:

- `rg-shared`

## Kubernetes-Architektur

### Host-Cluster

Der Host-Cluster ist der eigentliche AKS-Cluster. Dort laufen die gemeinsamen Plattformdienste.

Empfohlene gemeinsame Komponenten:

- Ingress Controller
- External Secrets Operator oder Secrets Store CSI Driver
- Monitoring, z. B. Azure Monitor oder Prometheus/Grafana
- Storage-Anbindung an Azure
- optional Headlamp oder andere Admin-Oberflaechen

### vCluster fuer Anwendung A

Im Host-Cluster wird ein dauerhafter `vCluster` fuer Anwendung A betrieben.

Der vCluster dient als fachlich getrennte Kubernetes-Umgebung fuer:

- Deployments der Anwendung
- Konfigurationen und Releases
- RBAC fuer Tester oder verantwortliche Teams
- eigenstaendige Release-Zyklen innerhalb der Anwendungsumgebung

Damit ergibt sich folgende Trennung:

- Plattformteam verwaltet AKS, Ingress, Identities, Secret-Integration und Storage-Basis
- Anwendungsteam oder Tester verwalten Releases innerhalb des vClusters

## Datenbankanbindung

Die Datenbank wird nicht durch Terraform fuer dieses Vorhaben erzeugt, da bereits ein `PostgreSQL Flexible Server` vorhanden ist.

Empfehlung fuer die Anbindung:

- Der Connection String wird nicht direkt in Helm-Values abgelegt.
- Der Connection String wird in `Azure Key Vault` gespeichert.
- Ein Cluster-Mechanismus wie `External Secrets Operator` oder `Secrets Store CSI Driver` uebernimmt die Bereitstellung im Cluster.
- Die Anwendung liest den Connection String aus einem Kubernetes Secret.

Vorteile:

- keine sensiblen Daten im Git-Repository
- klare Trennung zwischen Infrastruktur, Deployment und Geheimnissen
- spaetere Rotation einfacher moeglich

## Speicherempfehlung

Da die Anwendung persistenten externen Speicher benoetigt und dieser ausserhalb der Cluster-Resource-Group liegen soll, sollte der Speicher als separate Azure-Ressource verwaltet werden.

Fuer den Start ist folgende Annahme sinnvoll:

- Falls mehrere Pods oder mehrere Knoten denselben Speicher gemeinsam benoetigen, ist `Azure Files` der pragmatische Standard.
- Falls nur ein einzelnes Replica mit exklusivem Schreibzugriff arbeitet, kann auch blockbasierter Speicher sinnvoll sein.

Vorlaeufige Empfehlung fuer die Zielarchitektur v1:

- `Azure Files` als persistenter Speicher fuer Anwendung A

Begruendung:

- einfache Einbindung in Kubernetes
- gut geeignet fuer gemeinsam nutzbaren persistenten Dateispeicher
- passt oft besser zu dauerhaften Testumgebungen als streng podgebundener Blockspeicher

## Deployment-Modell

Die Anwendung wird mit `Helm` in den vCluster ausgerollt.

Empfohlene Inhalte des Helm-Charts:

- Deployment oder StatefulSet, je nach Anwendung
- Service
- Ingress
- PVC-Nutzung fuer persistenten Speicher
- Referenz auf Secret fuer den PostgreSQL Connection String
- Konfiguration fuer Image aus der Azure Container Registry
- mandantenbezogene Anwendungskonfiguration

Faustregel:

- `Terraform` erzeugt und verbindet Infrastruktur.
- `Helm` deployt und konfiguriert die Anwendung.

## Terraform-Verantwortung

Terraform sollte in diesem Vorhaben fuer folgende Themen zustaendig sein:

- AKS-Plattform
- Netzwerk und Identity-Anbindung
- Storage-Ressourcen fuer Anwendung A
- gegebenenfalls Anbindung an Key Vault
- Referenzierung oder Integration bestehender Ressourcen wie ACR und PostgreSQL

Terraform sollte nicht fuer das eigentliche Anwendungsdeployment verwendet werden, solange `Helm` diese Rolle uebernimmt.

## Zugriffsmodell

Die Umgebung ist dauerhaft. Daher muss der Tester Releases eigenstaendig steuern koennen, ohne die Plattform selbst zu veraendern.

Empfohlenes Modell:

- Plattform-Admins haben Zugriff auf den Host-Cluster.
- Tester oder Anwendungsteam erhalten Zugriff auf den vCluster von Anwendung A.
- Deployments werden im vCluster per `Helm` oder spaeter per CI/CD ausgerollt.

Zu klaerende Detailfrage fuer die naechste Phase:

- Erhaelt der Tester direkten `kubectl`- und `helm`-Zugriff auf den vCluster oder nur eine eingeschraenkte Bedienoberflaeche?

## Grafische Oberflaeche

Fuer den Start wird eine einfache grafische Oberflaeche empfohlen.

Pragmatische Optionen:

- `Lens` fuer Admins und technisch versierte Nutzer
- `Headlamp` als schlanke Weboberflaeche

Vorlaeufige Empfehlung:

- `Headlamp` fuer einfache Cluster-Sicht
- optional `Lens` fuer Plattformbetreiber

`Rancher` ist moeglich, waere fuer diesen ersten Zuschnitt aber wahrscheinlich schwergewichtiger als noetig.

## Lokaler Lern- und Testpfad

Vor AKS sollte das Modell lokal nachvollzogen werden.

Empfohlene erste Phase:

1. Lokalen Host-Cluster mit `kind` aufsetzen.
2. `vCluster` fuer Anwendung A erstellen.
3. Eine einfache Beispielanwendung mit `Helm` deployen.
4. Persistenz lokal ueber PVC simulieren.
5. Secret-Struktur fuer PostgreSQL Connection String vorbereiten.
6. Spaeter AKS-spezifische Integrationen fuer ACR, Azure Files und Key Vault nachziehen.

Ziel dieser Phase:

- Verstaendnis fuer Host-Cluster und vCluster
- Verstaendnis fuer Helm-Deployments im vCluster
- saubere Trennung von Infrastruktur, Secrets und Anwendungskonfiguration

## Offene Entscheidungen fuer die naechste Ausarbeitung

Die folgenden Punkte sollten als naechstes festgelegt werden:

- genaue Speicheranforderung der Anwendung
- Art des Kubernetes-Workloads: `Deployment` oder `StatefulSet`
- Zugriffspfad fuer Tester: direkt per CLI oder ueber GUI/CI
- URL- und Ingress-Modell fuer die dauerhafte Testumgebung
- Secret-Mechanismus: `External Secrets Operator` oder `Secrets Store CSI Driver`
- Struktur der Terraform-Stacks fuer Plattform, Shared Services und State-Ressourcen

## Naechster sinnvoller Schritt

Im naechsten Schritt sollte eine konkrete technische Soll-Architektur Phase 2 beschrieben werden mit:

- Terraform-Layern
- Helm-Chart-Struktur fuer Anwendung A
- lokalem Start-Setup
- Betriebsmodell fuer Tester
- Entscheidungsvorlage fuer Storage und Secret-Handling
