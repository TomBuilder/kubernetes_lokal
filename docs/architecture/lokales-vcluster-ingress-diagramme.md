# Lokale vCluster- und Ingress-Diagramme

Diese Diagramme beschreiben den aktuell getesteten lokalen Aufbau mit `kind`, `vCluster`, `ingress-nginx` und zwei getrennten Testerinstanzen.

## Request-Pfad vom Browser bis zum Pod am Beispiel `tester1`

```mermaid
flowchart LR
    A["Browser<br/>http://tester1.app-a.local:8080"] --> B["Windows hosts-Datei<br/>tester1.app-a.local -> 127.0.0.1"]
    B --> C["kind Port-Mapping<br/>localhost:8080 -> NodePort 30080"]
    C --> D["Host-Cluster Service<br/>ingress-nginx/ingress-nginx-controller"]
    D --> E["ingress-nginx Controller<br/>liest Ingress-Regeln"]
    E --> F["Host-Cluster Ingress<br/>vcluster-app-a/tester1-app-a-x-default-x-tester1-app-a<br/>Host: tester1.app-a.local"]
    F --> G["synchronisierter Service im Host-Cluster<br/>vcluster-app-a/tester1-app-a-x-default-x-tester1-app-a:80"]
    G --> H["synchronisierter App-Pod im Host-Cluster<br/>vcluster-app-a/tester1-app-a-...-x-default-x-tester1-app-a"]
```

## Schichtenmodell mit Host-Cluster und vCluster

```mermaid
flowchart TB
    subgraph W["Windows / Docker Desktop"]
        B["Browser"]
        H["hosts-Datei<br/>tester1.app-a.local / tester2.app-a.local -> 127.0.0.1"]
        K["kind Node-Container<br/>host-cluster-control-plane"]
    end

    subgraph HC["Host-Cluster (Kontext: kind-host-cluster)"]
        IC["Namespace ingress-nginx<br/>Pod: ingress-nginx-controller-6c7cd85885-krdpj<br/>Service: ingress-nginx-controller"]
        VC["Namespace vcluster-app-a<br/>Pod: app-a-0"]
        HS["synchronisierte Ressourcen aus dem vCluster<br/>Ingress/Service/Pod fuer tester1 und tester2<br/>z. B. tester1-app-a-x-default-x-tester1-app-a<br/>DNS: kube-dns-x-kube-system-x-app-a"]
    end

    subgraph V["vCluster app-a (Kontext: vcluster_app-a_vcluster-app-a_kind-host-cluster)"]
        VI["Ingress default/tester1-app-a und default/tester2-app-a<br/>Hosts: tester1.app-a.local / tester2.app-a.local"]
        VS["Services default/tester1-app-a und default/tester2-app-a"]
        VP["Pods default/tester1-app-a-... und default/tester2-app-a-..."]
        VD["CoreDNS kube-system/coredns-79cf5f4c56-72br8"]
    end

    B --> H
    H --> K
    K --> IC
    VC --> V
    VI --> HS
    VS --> HS
    VP --> HS
    IC --> HS
```

## Zuordnung der wichtigsten Ressourcen

- Host-Cluster-System: `kube-apiserver`, `etcd`, `coredns`, `kube-proxy`, `kindnet`
- Host-Cluster-Ingress: `ingress-nginx-controller`
- vCluster-Laufzeit im Host: `vcluster-app-a/app-a-0`
- Apps im vCluster: `default/tester1-app-a` und `default/tester2-app-a`
- In den Host synchronisierte App-Ressourcen: z. B. `vcluster-app-a/tester1-app-a-x-default-x-tester1-app-a`

## Lesart

- Der Browser spricht nie direkt mit einem Pod.
- Der Einstieg von aussen ist der `ingress-nginx` Service im Host-Cluster.
- Der `Ingress` bestimmt anhand von Hostname und Pfad, welcher Service angesprochen wird.
- Der Service leitet den Request an einen passenden Pod weiter.
- Der `vCluster` ist logisch ein eigener Cluster, laeuft technisch aber als Workload im Host-Cluster.
