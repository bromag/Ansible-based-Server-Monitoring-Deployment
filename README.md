# Projektidee: Automatisierte Monitoring-Umgebung mit Ansible

In unserem Projekt möchten wir mit Ansible eine automatisierte Monitoring-Umgebung aufbauen. Dabei wird ein zentraler Monitoring-Server mit Prometheus und Grafana installiert und konfiguriert. Zusätzlich werden zwei weitere Linux-Server als überwachte Systeme eingebunden. Auf diesen Servern wird der Node Exporter installiert, damit Systemdaten wie CPU-Auslastung, RAM-Verbrauch, Festplattenbelegung, Netzwerktraffic und Uptime gesammelt werden können.

Prometheus ruft diese Metriken regelmässig ab und speichert sie. Grafana wird anschliessend automatisch mit Prometheus als Datenquelle verbunden und stellt die gesammelten Daten in Dashboards dar. Optional soll zusätzlich ein Blackbox Exporter eingesetzt werden, um die Erreichbarkeit von Diensten wie HTTP oder SSH zu prüfen.

Ziel des Projektes ist es, die komplette Installation und Grundkonfiguration der Monitoring-Umgebung reproduzierbar mit Ansible zu automatisieren.

## Architektur grosso modo

Die Umgebung besteht aus drei Linux-Nodes in einem gemeinsamen privaten Netzwerk:

### Monitoring-Server

- Prometheus
- Grafana
- optional Blackbox Exporter
- sammelt und visualisiert die Daten

### Server 1

- Beispiel: Webserver mit Nginx
- Node Exporter
- liefert Systemmetriken an Prometheus

### Server 2

- Beispiel: Appserver oder Datenbankserver# Projektidee: Automatisierte Monitoring-Umgebung mit Ansible

In unserem Projekt möchten wir mit Ansible eine automatisierte Monitoring-Umgebung aufbauen. Dabei wird ein zentraler Monitoring-Server mit Prometheus und Grafana installiert und konfiguriert. Zusätzlich werden zwei weitere Linux-Server als überwachte Systeme eingebunden. Auf diesen Servern wird der Node Exporter installiert, damit Systemdaten wie CPU-Auslastung, RAM-Verbrauch, Festplattenbelegung, Netzwerktraffic und Uptime gesammelt werden können.

Prometheus ruft diese Metriken regelmässig ab und speichert sie. Grafana wird anschliessend automatisch mit Prometheus als Datenquelle verbunden und stellt die gesammelten Daten in Dashboards dar. Optional soll zusätzlich ein Blackbox Exporter eingesetzt werden, um die Erreichbarkeit von Diensten wie HTTP oder SSH zu prüfen.

Ziel des Projektes ist es, die komplette Installation und Grundkonfiguration der Monitoring-Umgebung reproduzierbar mit Ansible zu automatisieren.

## Architektur grosso modo

Die Umgebung besteht aus drei Linux-Nodes in einem gemeinsamen privaten Netzwerk:

### Monitoring-Server

- Prometheus
- Grafana
- optional Blackbox Exporter
- sammelt und visualisiert die Daten

### Server 1

- Beispiel: Webserver mit Nginx
- Node Exporter
- liefert Systemmetriken an Prometheus

### Server 2

- Beispiel: Appserver oder Datenbankserver
- Node Exporter
- liefert ebenfalls Systemmetriken an Prometheus

## Netzwerk / Datenfluss

Alle Server befinden sich im gleichen privaten Netzwerk. Prometheus auf dem Monitoring-Server verbindet sich regelmässig mit den Node Exportern auf den überwachten Servern über Port 9100.

Grafana greift lokal auf Prometheus zu und zeigt die Daten über die Weboberfläche auf Port 3000 an. Falls der Blackbox Exporter verwendet wird, prüft dieser zusätzlich, ob bestimmte Dienste wie HTTP oder SSH erreichbar sind.

text Benutzer    |    | Webbrowser Port 3000    v Monitoring-Server Grafana + Prometheus + optional Blackbox Exporter    |    | Prometheus sammelt Metriken    | Port 9100    v Server 1: Webserver + Node Exporter  Monitoring-Server    |    | Prometheus sammelt Metriken    | Port 9100    v Server 2: Appserver/DB-Server + Node Exporter 

## Was mit Ansible automatisiert wird

- Grundinstallation und Systemvorbereitung der Server
- Installation von Prometheus
- Installation von Grafana
- Installation von Node Exporter auf den überwachten Servern
- Konfiguration der Prometheus Targets
- Einrichtung von Grafana mit Prometheus als Datenquelle
- Import eines fertigen Grafana Dashboards
- Konfiguration der benötigten Firewall-Regeln
- Starten und Aktivieren aller benötigten Services
- Node Exporter
- liefert ebenfalls Systemmetriken an Prometheus

## Netzwerk / Datenfluss

Alle Server befinden sich im gleichen privaten Netzwerk. Prometheus auf dem Monitoring-Server verbindet sich regelmässig mit den Node Exportern auf den überwachten Servern über Port 9100.

Grafana greift lokal auf Prometheus zu und zeigt die Daten über die Weboberfläche auf Port 3000 an. Falls der Blackbox Exporter verwendet wird, prüft dieser zusätzlich, ob bestimmte Dienste wie HTTP oder SSH erreichbar sind.

text Benutzer    |    | Webbrowser Port 3000    v Monitoring-Server Grafana + Prometheus + optional Blackbox Exporter    |    | Prometheus sammelt Metriken    | Port 9100    v Server 1: Webserver + Node Exporter  Monitoring-Server    |    | Prometheus sammelt Metriken    | Port 9100    v Server 2: Appserver/DB-Server + Node Exporter 

## Was mit Ansible automatisiert wird

- Grundinstallation und Systemvorbereitung der Server
- Installation von Prometheus
- Installation von Grafana
- Installation von Node Exporter auf den überwachten Servern
- Konfiguration der Prometheus Targets
- Einrichtung von Grafana mit Prometheus als Datenquelle
- Import eines fertigen Grafana Dashboards
- Konfiguration der benötigten Firewall-Regeln
- Starten und Aktivieren aller benötigten Services