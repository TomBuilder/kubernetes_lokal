# Naechster Schritt: Echter Worker im lokalen vCluster-Setup

## Ausgangslage

Der aktuelle lokale Stand ist:

- `kind` als Host-Cluster
- ein `vCluster` fuer Anwendung A
- `ingress-nginx` fuer den Zugriff von aussen
- zwei getrennte Testerinstanzen `tester1` und `tester2`
- je Tester:
  - ein Web-Deployment
  - ein Worker-Deployment
  - ein eigener PVC
  - ein eigener Ingress-Host
- unterschiedliche Worker-Versionen pro Tester
- Host-Metriken ueber `metrics-server`

Der aktuelle Demo-Worker dient vor allem zum Verstaendnis von:

- getrennten Releases pro Tester
- unterschiedlichen Versionen pro Tester
- Rollouts und Versionswechsel
- Logs und Beobachtbarkeit

## Randbedingungen

Fuer den naechsten fachlichen Schritt gelten folgende Rahmenbedingungen:

- Die echten Worker-Images koennen lokal ueber Docker Desktop bezogen oder gebaut werden.
- Die Datenbank liegt lokal ausserhalb des Clusters.
- Es wird eine echte Ablage auf der lokalen Platte benoetigt, um Konfigurationsdateien abzulegen.
- Logging kann zunaechst ueber Konsole erfolgen.
- Serilog ist fuer Logging bereits als passendes Muster vorgesehen.

## Zielbild

Das Ziel ist ein lokales Setup, in dem echte Worker schrittweise in das bestehende Muster ueberfuehrt werden:

- pro Tester eine eigene Worker-Kette
- pro Worker-Typ ein eigenes Deployment
- getrennte Versionen pro Tester
- spaeter `scale-to-zero` fuer Worker

Die Trennung zwischen den Testern soll fachlich ueber eigene Releases und inhaltlich ueber Datenbankfilter und Konfiguration erfolgen.

## Wichtige Begriffe

Mit `Worker-Typ` ist eine fachlich unterschiedliche Hintergrundaufgabe gemeint, zum Beispiel:

- Import
- Validierung
- Export
- Synchronisation

Eine reale Kette kann also aus mehreren Worker-Typen bestehen, wobei jeder Worker-Typ pro Tester als eigenes Deployment laeuft.

## Empfohlene Reihenfolge

Der naechste Ausbau sollte bewusst schrittweise erfolgen.

### Phase 1: Erster echter Worker

Ziel:

- einen echten Worker-Typ in das bestehende Setup integrieren
- echtes Worker-Image statt Demo-Worker
- DB-Zugriff aktiv
- Serilog auf Konsole
- weiterhin getrennte Versionen fuer `tester1` und `tester2`

Noch nicht enthalten:

- Host-Mount fuer Konfigurationsdateien
- KEDA / scale-to-zero
- komplette Worker-Kette

Warum zuerst so:

- Container, Datenbankzugriff und Versionstrennung werden real validiert
- Fehlerursachen bleiben ueberschaubar
- der Schritt ist gross genug, aber noch kontrollierbar

### Phase 2: Konfigurationsdateien von der lokalen Platte

Ziel:

- Konfigurationsdateien ausserhalb des Clusters auf echter Host-Ablage
- Einbindung ueber Host-Mount
- saubere Trennung pro Tester

Empfohlene Struktur:

- `...\\runtime-config\\tester1\\...`
- `...\\runtime-config\\tester2\\...`

Warum als eigener Schritt:

- Host-Mounts bringen lokale Pfad-, Berechtigungs- und Portabilitaetsthemen mit
- diese Themen sollten nicht gleichzeitig mit dem ersten echten Worker vermischt werden

### Phase 3: KEDA / scale-to-zero fuer Worker

Ziel:

- Worker standardmaessig auf `0`
- Hochskalierung nur bei vorhandener Arbeit
- getrennte Skalierung pro Tester und pro Worker-Typ

Naheliegendes Modell:

- Trigger ueber Datenbankabfragen
- Filter nach:
  - Tester-/Umgebungskennung
  - Worker-Typ
  - Status

Beispielidee:

```sql
select count(*)
from work_items
where environment = 'tester1'
  and worker_type = 'import'
  and status = 'pending';
```

Warum erst spaeter:

- zuerst muss der echte Worker fachlich sauber laufen
- erst danach sollte Autoscaling als eigener Mechanismus hinzukommen

Technisch bietet sich fuer das bestehende Helm-Chart ein `ScaledObject` je Worker-Deployment an.
Der Trigger kann ueber dieselbe DB-Verbindung laufen, die auch der Worker selbst nutzt.
Fuer den lokalen Pilot reicht dafuer zunaechst ein einziger PostgreSQL-Trigger je Tester und Worker-Typ.

## Architekturannahmen fuer den ersten echten Worker

Der erste echte Worker-Prototyp sollte:

- als eigener Container laufen
- per Helm im bestehenden `vCluster` ausgerollt werden
- per Konfiguration wissen, fuer welchen Tester er arbeitet
- eine Verbindung zur lokalen externen Datenbank aufbauen
- per Serilog auf Konsole loggen
- offene Arbeit lesen, verarbeiten und Status zurueckschreiben

Die fachliche Trennung sollte mindestens ueber eines dieser Merkmale moeglich sein:

- Testerkennung
- Umgebungskennung
- Mandant
- Mandantengruppe

## Noch nicht abschliessend entschieden

Vor der Umsetzung des ersten echten Workers sind noch diese Punkte fachlich zu klaeren:

- Welcher echte Worker-Typ wird als erster Pilot genommen?
- Wie genau erreicht der Pod die lokale Datenbank?
- Welche minimale Konfiguration wird per Env Var/Secret geliefert?
- Welche Konfiguration muss spaeter zwingend als Datei vorliegen?

## Festgelegt fuer den lokalen Pilot

Fuer den naechsten lokalen Ausbau ist als erstes echtes Worker-Image vorgesehen:

- `conregipsentw.azurecr.io/zvd-priorisierung:2.0.0.25447`

Dieser Stand ersetzt im lokalen Setup den Demo-Worker als technische Pilotbasis fuer Phase 1.

Der vorhandene lokale Startpunkt fuer dieses Image ist:

- `D:\Projekte\ipsYdion\IpsydionGeva\Services\ZvdPriorisierung\docker_build.env`

Daraus ergeben sich fuer das Kubernetes-Setup mindestens diese Anforderungen:

- .NET-Konfiguration ueber Env Vars mit `__` statt `:`
- zwei Connection-String-Eintraege fuer PostgreSQL
- `ServiceConfiguration__InstallationEnvironment=Services`
- Serilog auf Konsole und Datei
- beschreibbarer Mount fuer die Laufzeitdaten, lokal derzeit unter `/configdata`
- fuer `kind` wird der Windows-Pfad `D:\Testumgebung\ZVD` zusaetzlich per `extraMounts` in den Node eingebunden und im Worker lokal per `hostPath` verwendet

Offen bleibt weiterhin:

- welcher fachliche Worker-Typ innerhalb von `zvd-priorisierung` damit genau pilotiert wird
- welche minimale DB-Konfiguration dieser Worker konkret benoetigt
- ob fuer `tester1` und `tester2` direkt unterschiedliche Tags genutzt werden sollen oder zunaechst derselbe Stand ausgerollt wird

## Empfehlung fuer die Wiederaufnahme

Wenn die Arbeit in einem anderen Thread fortgesetzt wird, ist der naechste sinnvolle Einstieg:

1. Einen echten Worker-Typ auswaehlen.
2. Die minimale fachliche Aufgabe dieses Workers beschreiben.
3. Die benoetigten Konfigurationswerte benennen.
4. Dann Phase 1 umsetzen: echter Worker mit DB + Logging, noch ohne Host-Mount und ohne KEDA.
