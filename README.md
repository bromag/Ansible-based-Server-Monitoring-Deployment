# Automatisierte Server- und Monitoring-Umgebung mit Ansible

## 1. Projektübersicht

In diesem Projekt wurde eine vollständige Server- und Monitoring-Umgebung mit Ansible automatisiert aufgebaut.

Die Umgebung besteht aus vier Linux-Servern:

- `web-server`
- `app-server`
- `db-server`
- `monitoring-server`

Die virtuellen Maschinen werden mit Vagrant erstellt. Unterstützt werden:

- Parallels Desktop
- VirtualBox
- VMware Fusion beziehungsweise VMware Workstation

Ansible übernimmt danach die Installation und Konfiguration aller benötigten Dienste.

---

## 2. Ziel des Projektes

Ziel des Projektes ist es, eine vollständige Testumgebung automatisch und reproduzierbar bereitzustellen.

Folgende Komponenten werden installiert und konfiguriert:

- Nginx als Reverse Proxy
- Python-Webapplikation mit Flask
- Gunicorn als Application Server
- MariaDB als Datenbank
- Prometheus für das Monitoring
- Grafana für die Visualisierung
- Node Exporter auf allen Servern

Die Umgebung kann entweder vollständig lokal oder mit einem separaten Ansible-Server ausgeführt werden.

---

## 3. Architektur

| Server | Aufgabe | Komponenten |
|---|---|---|
| `web-server` | Einstiegspunkt für die Webapplikation | Nginx, Node Exporter |
| `app-server` | Ausführung der Webapplikation | Python, Flask, Gunicorn, Node Exporter |
| `db-server` | Speicherung der Applikationsdaten | MariaDB, Node Exporter |
| `monitoring-server` | Überwachung und Visualisierung | Prometheus, Grafana, Node Exporter |

### Datenfluss der Webapplikation

```text
Benutzer
   |
   | HTTP Port 80
   v
web-server
Nginx Reverse Proxy
   |
   | HTTP Port 5000
   v
app-server
Python / Flask / Gunicorn
   |
   | MariaDB Port 3306
   v
db-server
MariaDB
```

### Datenfluss des Monitorings

```text
Node Exporter auf allen Servern
   |
   | Port 9100
   v
Prometheus
   |
   v
Grafana
   |
   v
Dashboard im Webbrowser
```

---

## 4. Umgesetzte Komponenten

### 4.1 Webserver

Auf dem `web-server` wird Nginx installiert.

Nginx nimmt die HTTP-Anfragen entgegen und leitet sie an die Python-Webapplikation auf dem `app-server` weiter.

Die Webapplikation ist über folgende Adresse erreichbar:

```text
http://<WEB-SERVER-IP>
```

### 4.2 Applikationsserver

Auf dem `app-server` läuft eine Python-Webapplikation mit Flask und Gunicorn.

Die Anwendung stellt folgende Endpunkte bereit:

| Endpunkt | Funktion |
|---|---|
| `/` | Startseite |
| `/health` | Prüft, ob die Applikation läuft |
| `/db` | Prüft die Verbindung zur Datenbank |

Die Anwendung läuft intern auf Port `5000`.

### 4.3 Datenbankserver

Auf dem `db-server` wird MariaDB installiert.

Ansible erstellt automatisch:

- die Datenbank `appdb`
- den Benutzer `appuser`
- die benötigten Berechtigungen
- die Konfiguration für externe Verbindungen

### 4.4 Monitoring-Server

Auf dem `monitoring-server` werden Prometheus und Grafana installiert.

Prometheus ist erreichbar unter:

```text
http://<MONITORING-IP>:9090
```

Grafana ist erreichbar unter:

```text
http://<MONITORING-IP>:3000
```

### 4.5 Node Exporter

Node Exporter wird auf allen vier Servern installiert.

Er liefert unter anderem folgende Informationen:

- CPU-Auslastung
- Arbeitsspeicher
- Festplattenbelegung
- Netzwerkverkehr
- Uptime
- System Load

Die Metriken sind auf jedem Server unter folgender Adresse verfügbar:

```text
http://<SERVER-IP>:9100/metrics
```

---

## 5. Projektstruktur

```text
Ansible-based-Server-Monitoring-Deployment/
├── .gitignore
├── README.md
├── start-lab.sh
├── start-vagrant-only.sh
├── prepare-ansible-server.sh
├── deploy-from-ansible-server.sh
├── images/
│   └── ansible-automation.png
├── vagrant/
│   └── Vagrantfile
└── ansible/
    ├── ansible.cfg
    ├── site.yml
    ├── inventory/
    │   └── hosts.ini.example
    ├── group_vars/
    │   └── all.yml
    └── roles/
        ├── common/
        ├── nginx/
        ├── app/
        ├── mariadb/
        ├── node_exporter/
        ├── prometheus/
        └── grafana/
```

---

## 6. Automatisierung mit Ansible

Ansible übernimmt folgende Aufgaben:

- Vorbereitung der Linux-Server
- Installation von Nginx
- Konfiguration des Reverse Proxys
- Installation von Python
- Installation von Flask und Gunicorn
- Bereitstellung der Webapplikation
- Erstellung des systemd-Services
- Installation und Konfiguration von MariaDB
- Erstellung der Datenbank und des Benutzers
- Installation von Node Exporter
- Installation und Konfiguration von Prometheus
- Konfiguration der Prometheus-Targets
- Installation und Konfiguration von Grafana
- Provisionierung der Prometheus-Datenquelle
- Bereitstellung des Grafana-Dashboards
- Start und Aktivierung aller Services

---

## 7. Ansible-Rollen

Die Konfiguration wurde in verschiedene Ansible-Rollen aufgeteilt.

### `common`

Installiert allgemeine Pakete und bereitet die Server vor.

### `nginx`

Installiert Nginx und erstellt die Reverse-Proxy-Konfiguration.

### `app`

Installiert und konfiguriert die Python-Webapplikation.

### `mariadb`

Installiert MariaDB und erstellt Datenbank und Benutzer.

### `node_exporter`

Installiert Node Exporter auf allen Servern.

### `prometheus`

Installiert Prometheus und konfiguriert die Monitoring-Targets.

### `grafana`

Installiert Grafana und richtet die Prometheus-Datenquelle sowie das Dashboard ein.

---

## 8. Lokale Komplettausführung

Für die vollständige lokale Ausführung wird das Script `start-lab.sh` verwendet.

Das Script:

1. fragt den Virtualisierungsanbieter ab
2. startet die vier Vagrant-VMs
3. ermittelt die IP-Adressen
4. erstellt das Ansible-Inventory
5. testet die Verbindungen
6. führt das Ansible-Playbook aus
7. prüft die wichtigsten Services

### Ausführung

```bash
chmod +x start-lab.sh
./start-lab.sh
```

Das Script wird ohne `sudo` gestartet.

Anschliessend wird der gewünschte Provider ausgewählt:

```text
1) Parallels Desktop
2) VirtualBox
3) VMware Fusion / Workstation
```

Nach erfolgreicher Ausführung werden die Adressen der Anwendungen angezeigt.

---

## 9. Getrennte Ausführung mit Ansible-Server

Die getrennte Ausführung besteht aus drei Schritten.

### 9.1 Ansible-Server vorbereiten

Auf dem Ansible-Server wird zuerst folgendes Script ausgeführt:

```bash
chmod +x prepare-ansible-server.sh
sudo ./prepare-ansible-server.sh
```

Das Script:

- aktualisiert den Server
- installiert Git, Ansible, Python und SSH
- erstellt einen SSH-Key für das Projekt

Die SSH-Keys werden unter folgenden Pfaden erstellt:

```text
~/.ssh/ansible_lab
~/.ssh/ansible_lab.pub
```

Der private Key bleibt auf dem Ansible-Server.

Der öffentliche Key wird später auf die vier VMs übertragen.

### 9.2 Vagrant-VMs erstellen

Auf dem lokalen Computer wird danach folgendes Script ausgeführt:

```bash
chmod +x start-vagrant-only.sh
./start-vagrant-only.sh
```

Das Script:

- fragt den Vagrant-Provider ab
- fragt die Verbindung zum Ansible-Server ab
- lädt den öffentlichen SSH-Key herunter
- erstellt die vier VMs
- installiert den öffentlichen Key auf allen VMs
- zeigt die IP-Adressen der VMs an

Folgende Angaben werden benötigt:

```text
IP-Adresse oder Hostname des Ansible-Servers
SSH-Benutzer des Ansible-Servers
Pfad zum öffentlichen SSH-Key
```

Der Standardpfad des öffentlichen Keys ist:

```text
~/.ssh/ansible_lab.pub
```

Wenn der Ansible-Server ebenfalls eine Vagrant-VM ist, lautet der Benutzer normalerweise `vagrant`.

Danach kann eine Passwortabfrage erscheinen. Bei einer Vagrant-VM mit Standardzugangsdaten lautet das Passwort normalerweise ebenfalls `vagrant`.

Nach erfolgreicher Ausführung werden die IP-Adressen angezeigt:

```text
web-server:        <IP-Adresse>
app-server:        <IP-Adresse>
db-server:         <IP-Adresse>
monitoring-server: <IP-Adresse>
```

### 9.3 Deployment ausführen

Auf dem Ansible-Server wird anschliessend folgendes Script ausgeführt:

```bash
chmod +x deploy-from-ansible-server.sh
sudo ./deploy-from-ansible-server.sh
```

Das Script:

- klont oder aktualisiert das GitHub-Repository
- fragt die vier VM-IP-Adressen ab
- erstellt das Ansible-Inventory
- testet die SSH-Verbindungen
- führt das Playbook aus
- prüft die Services

Repository:

```text
https://github.com/bromag/Ansible-based-Server-Monitoring-Deployment.git
```

Nach erfolgreicher Ausführung werden die Adressen angezeigt:

```text
Webapplikation:
  http://<WEB-IP>

Prometheus:
  http://<MONITORING-IP>:9090

Grafana:
  http://<MONITORING-IP>:3000
```

---

## 10. Reihenfolge der getrennten Ausführung

### Schritt 1: Ansible-Server vorbereiten

```bash
sudo ./prepare-ansible-server.sh
```

### Schritt 2: VMs erstellen

```bash
./start-vagrant-only.sh
```

### Schritt 3: Deployment starten

```bash
sudo ./deploy-from-ansible-server.sh
```

---

## 11. Netzwerkvoraussetzungen

Der Ansible-Server muss die vier VMs über das Netzwerk erreichen können.

Test mit Ping:

```bash
ping <VM-IP>
```

Test mit SSH:

```bash
ssh -i ~/.ssh/ansible_lab vagrant@<VM-IP>
```

Wenn die VMs in einem Host-only-Netzwerk auf einem anderen Computer laufen, kann der Zugriff blockiert sein.

Mögliche Lösungen:

- Bridged Networking
- Routing zwischen den Netzwerken
- Ansible-Server im gleichen Netzwerk
- lokale Ausführung mit `start-lab.sh`

---

## 12. Grafana verwenden

Grafana ist unter folgender Adresse erreichbar:

```text
http://<MONITORING-IP>:3000
```

### Anmeldung

Für die Testumgebung werden folgende Zugangsdaten verwendet:

```text
Benutzername: admin
Passwort: admin
```

Nach der ersten Anmeldung fordert Grafana dazu auf, ein neues Passwort festzulegen.

Da es sich nur um eine Testumgebung handelt, kann dieser Schritt mit **Skip** übersprungen werden.

In einer produktiven Umgebung muss das Standardpasswort geändert werden.

### Dashboard öffnen

Nach der Anmeldung:

1. links **Dashboards** auswählen
2. den Ordner **Infrastructure** öffnen
3. **Node Exporter Full** auswählen
4. oben beim Filter **Job** den Wert `node_exporter` auswählen

Danach werden die Metriken aller vier Server angezeigt.

Über den Filter **Instance** kann ein einzelner Server ausgewählt werden.

---

## 13. Prometheus prüfen

Prometheus ist unter folgender Adresse erreichbar:

```text
http://<MONITORING-IP>:9090
```

Die überwachten Systeme können unter folgender Adresse geprüft werden:

```text
http://<MONITORING-IP>:9090/targets
```

Alle Node-Exporter-Targets sollten den Status `UP` anzeigen.

---

## 14. Funktionstests

### Webapplikation

```bash
curl http://<WEB-SERVER-IP>/
```

### Health-Endpunkt

```bash
curl http://<WEB-SERVER-IP>/health
```

### Datenbankverbindung

```bash
curl http://<WEB-SERVER-IP>/db
```

### Node Exporter

```bash
curl http://<SERVER-IP>:9100/metrics
```

---

## 15. Git-Ignore

Die Datei `.gitignore` befindet sich im Hauptverzeichnis des Projektes.

Empfohlener Inhalt:

```gitignore
# Vagrant
.vagrant/

# Dynamisch erzeugtes Ansible-Inventory
ansible/inventory/hosts.ini

# macOS
.DS_Store

# Temporäre Dateien
*.tmp
*.log

# Python
__pycache__/
*.pyc
.venv/
venv/

# Editor-Dateien
.vscode/
.idea/

# SSH-Keys
*.pem
*.key
id_rsa
id_rsa.pub
id_ed25519
id_ed25519.pub
ansible_lab
ansible_lab.pub

# Umgebungsdateien und Secrets
.env
.env.*
```

Das echte Inventory wird automatisch erzeugt und nicht im Repository gespeichert.

---

## 16. Sicherheit

Folgende Massnahmen wurden umgesetzt:

- SSH-Key-Authentifizierung
- der private SSH-Key bleibt auf dem Ansible-Server
- nur der öffentliche SSH-Key wird auf die VMs übertragen
- `.vagrant/` wird nicht versioniert
- das automatisch erzeugte Inventory wird nicht versioniert
- Services laufen mit eigenen Benutzern
- MariaDB verwendet einen eigenen Benutzer

Da es sich um eine Testumgebung handelt, werden teilweise einfache Standardpasswörter verwendet.

Für eine produktive Umgebung wären zusätzliche Massnahmen notwendig:

- Ansible Vault
- stärkere Passwörter
- HTTPS
- Firewall-Regeln
- Backups
- eingeschränkter Zugriff auf Grafana und Prometheus

---

## 17. Aktueller Projektstand

Folgende Punkte wurden erfolgreich umgesetzt:

- vier Vagrant-VMs
- Auswahl des Virtualisierungsanbieters
- automatische Ermittlung der IP-Adressen
- automatische Erstellung des Inventory
- Nginx Reverse Proxy
- Python-Webapplikation
- MariaDB
- Node Exporter auf allen Servern
- Prometheus
- Grafana
- Grafana-Dashboard
- lokale Komplettausführung
- getrennte Ausführung mit Ansible-Server
- SSH-Key-Verteilung
- automatische Service-Prüfungen

---

## 18. Mögliche Erweiterungen

Das Projekt könnte später erweitert werden mit:

- Blackbox Exporter
- Alertmanager
- eigenen Grafana-Dashboards
- Firewall-Automatisierung
- Ansible Vault
- Backup-Automatisierung
- Benachrichtigungen bei Ausfällen

---

## 19. Fazit

Mit dem Projekt wurde eine vollständige Server- und Monitoring-Umgebung automatisiert aufgebaut.

Vagrant erstellt die virtuellen Maschinen. Ansible installiert und konfiguriert die benötigten Dienste.

Prometheus sammelt die Systemmetriken und Grafana stellt diese übersichtlich in Dashboards dar.

Durch die Aufteilung in verschiedene Rollen und Scripts bleibt das Projekt verständlich, reproduzierbar und erweiterbar.

---

## Architekturdiagramm

![Architekturdiagramm der Ansible-Umgebung](images/Ansible-Automation.png)
