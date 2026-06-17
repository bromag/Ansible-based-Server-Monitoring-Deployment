#!/usr/bin/env bash

set -Eeuo pipefail

# ==============================================================================
# Startscript für das Ansible Monitoring Lab
#
# Das Script:
#   1. fragt den gewünschten Virtualisierungsanbieter ab
#   2. startet alle Vagrant-VMs mit dem gewählten Provider
#   3. ermittelt automatisch die VM-IP-Adressen
#   4. erzeugt das Ansible-Inventory
#   5. prüft die Verbindungen
#   6. führt das vollständige Ansible-Playbook aus
#   7. prüft die wichtigsten Services
# ==============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAGRANT_DIR="${PROJECT_ROOT}/vagrant"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"
INVENTORY_FILE="${ANSIBLE_DIR}/inventory/hosts.ini"

VAGRANT_PROVIDER=""
PROVIDER_DIRECTORY=""

log() {
    printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

fail() {
    printf '\nFehler: %s\n' "$1" >&2
    exit 1
}

select_provider() {
    printf '\nVirtualisierungsanbieter auswählen:\n\n'
    printf '  1) Parallels Desktop\n'
    printf '  2) VirtualBox\n'
    printf '  3) VMware Fusion / Workstation\n\n'

    read -rp "Auswahl [1-3]: " provider_choice

    case "${provider_choice}" in
        1)
            VAGRANT_PROVIDER="parallels"
            PROVIDER_DIRECTORY="parallels"
            ;;
        2)
            VAGRANT_PROVIDER="virtualbox"
            PROVIDER_DIRECTORY="virtualbox"
            ;;
        3)
            VAGRANT_PROVIDER="vmware_desktop"
            PROVIDER_DIRECTORY="vmware_desktop"
            ;;
        *)
            fail "Ungültige Auswahl. Erlaubt sind 1, 2 oder 3."
            ;;
    esac

    log "Gewählter Provider: ${VAGRANT_PROVIDER}"
}

get_vm_ip() {
    local vm_name="$1"
    local vm_ip=""

    cd "${VAGRANT_DIR}"

    vm_ip="$(
        vagrant ssh "${vm_name}" \
            -c "hostname -I | awk '{print \$1}'" \
            2>/dev/null |
            tr -d '\r' |
            tail -n 1
    )"

    printf '%s' "${vm_ip}"
}

get_private_key() {
    local vm_name="$1"
    local key_path=""

    key_path="${VAGRANT_DIR}/.vagrant/machines/${vm_name}/${PROVIDER_DIRECTORY}/private_key"

    [[ -f "${key_path}" ]] ||
        fail "SSH-Key für ${vm_name} wurde nicht gefunden: ${key_path}"

    printf '%s' "${key_path}"
}

# ==============================================================================
# Voraussetzungen prüfen
# ==============================================================================

command -v vagrant >/dev/null 2>&1 ||
    fail "Vagrant ist nicht installiert."

command -v ansible >/dev/null 2>&1 ||
    fail "Ansible ist nicht installiert."

command -v ansible-playbook >/dev/null 2>&1 ||
    fail "ansible-playbook ist nicht installiert."

command -v ansible-galaxy >/dev/null 2>&1 ||
    fail "ansible-galaxy ist nicht installiert."

[[ -f "${VAGRANT_DIR}/Vagrantfile" ]] ||
    fail "Vagrantfile wurde nicht gefunden: ${VAGRANT_DIR}/Vagrantfile"

[[ -f "${ANSIBLE_DIR}/site.yml" ]] ||
    fail "Ansible-Playbook wurde nicht gefunden: ${ANSIBLE_DIR}/site.yml"

# ==============================================================================
# Provider auswählen und VMs starten
# ==============================================================================

select_provider

log "Starte die virtuellen Maschinen mit ${VAGRANT_PROVIDER}"

cd "${VAGRANT_DIR}"

if ! vagrant up --provider="${VAGRANT_PROVIDER}"; then
    fail "Die VMs konnten mit dem Provider ${VAGRANT_PROVIDER} nicht gestartet werden."
fi

log "Prüfe den Status der virtuellen Maschinen"

vagrant status

# ==============================================================================
# IP-Adressen ermitteln
# ==============================================================================

log "Ermittle die IP-Adressen"

WEB_IP="$(get_vm_ip web-server)"
APP_IP="$(get_vm_ip app-server)"
DB_IP="$(get_vm_ip db-server)"
MONITORING_IP="$(get_vm_ip monitoring-server)"

[[ -n "${WEB_IP}" ]] ||
    fail "IP von web-server konnte nicht ermittelt werden."

[[ -n "${APP_IP}" ]] ||
    fail "IP von app-server konnte nicht ermittelt werden."

[[ -n "${DB_IP}" ]] ||
    fail "IP von db-server konnte nicht ermittelt werden."

[[ -n "${MONITORING_IP}" ]] ||
    fail "IP von monitoring-server konnte nicht ermittelt werden."

printf '\nErmittelte IP-Adressen:\n'
printf '  web-server:        %s\n' "${WEB_IP}"
printf '  app-server:        %s\n' "${APP_IP}"
printf '  db-server:         %s\n' "${DB_IP}"
printf '  monitoring-server: %s\n' "${MONITORING_IP}"

# ==============================================================================
# SSH-Keys ermitteln
# ==============================================================================

log "Prüfe die SSH-Keys"

WEB_KEY="$(get_private_key web-server)"
APP_KEY="$(get_private_key app-server)"
DB_KEY="$(get_private_key db-server)"
MONITORING_KEY="$(get_private_key monitoring-server)"

# ==============================================================================
# Inventory erstellen
# ==============================================================================

mkdir -p "$(dirname "${INVENTORY_FILE}")"

log "Erstelle das Ansible-Inventory"

cat > "${INVENTORY_FILE}" <<EOF
[web]
web-server ansible_host=${WEB_IP} ansible_ssh_private_key_file=${WEB_KEY}

[app]
app-server ansible_host=${APP_IP} ansible_ssh_private_key_file=${APP_KEY}

[db]
db-server ansible_host=${DB_IP} ansible_ssh_private_key_file=${DB_KEY}

[monitoring]
monitoring-server ansible_host=${MONITORING_IP} ansible_ssh_private_key_file=${MONITORING_KEY}

[all:vars]
ansible_user=vagrant
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

printf '\nErstelltes Inventory:\n\n'
cat "${INVENTORY_FILE}"

# ==============================================================================
# Ansible vorbereiten
# ==============================================================================

log "Installiere benötigte Ansible Collections"

ansible-galaxy collection install ansible.mysql

cd "${ANSIBLE_DIR}"

log "Prüfe das Inventory"

ansible-inventory \
    --inventory "${INVENTORY_FILE}" \
    --graph

log "Prüfe die Syntax des Playbooks"

ansible-playbook \
    --inventory "${INVENTORY_FILE}" \
    site.yml \
    --syntax-check

log "Teste die Verbindung zu allen Servern"

ansible \
    --inventory "${INVENTORY_FILE}" \
    all \
    --module-name ping

# ==============================================================================
# Deployment starten
# ==============================================================================

log "Starte das vollständige Deployment"

ansible-playbook \
    --inventory "${INVENTORY_FILE}" \
    site.yml

# ==============================================================================
# Services prüfen
# ==============================================================================

log "Prüfe die wichtigsten Services"

ansible \
    --inventory "${INVENTORY_FILE}" \
    web-server \
    --become \
    --module-name command \
    --args "systemctl is-active nginx"

ansible \
    --inventory "${INVENTORY_FILE}" \
    app-server \
    --become \
    --module-name command \
    --args "systemctl is-active python-app"

ansible \
    --inventory "${INVENTORY_FILE}" \
    db-server \
    --become \
    --module-name command \
    --args "systemctl is-active mariadb"

ansible \
    --inventory "${INVENTORY_FILE}" \
    monitoring-server \
    --become \
    --module-name command \
    --args "systemctl is-active prometheus"

ansible \
    --inventory "${INVENTORY_FILE}" \
    monitoring-server \
    --become \
    --module-name command \
    --args "systemctl is-active grafana-server"

# ==============================================================================
# Abschluss
# ==============================================================================

printf '\n============================================================\n'
printf 'Deployment erfolgreich abgeschlossen.\n'
printf '============================================================\n'

printf '\nVerwendeter Provider:\n'
printf '  %s\n' "${VAGRANT_PROVIDER}"

printf '\nWebapplikation:\n'
printf '  http://%s\n' "${WEB_IP}"

printf '\nPrometheus:\n'
printf '  http://%s:9090\n' "${MONITORING_IP}"

printf '\nGrafana:\n'
printf '  http://%s:3000\n' "${MONITORING_IP}"
printf "  Benutzername: admin\n"
printf "  Passwort: admin\n"


printf '\n'