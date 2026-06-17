#!/usr/bin/env bash

set -Eeuo pipefail

# ==============================================================================
# Lokale Vagrant-VMs erstellen
#
# Das Script:
#   1. fragt den Virtualisierungsanbieter ab
#   2. lädt den öffentlichen SSH-Key vom Ansible-Server
#   3. startet die vier Vagrant-VMs
#   4. installiert den öffentlichen Key auf allen VMs
#   5. zeigt die automatisch vergebenen IP-Adressen
#
# Es führt kein Ansible-Playbook aus.
# ==============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAGRANT_DIR="${PROJECT_ROOT}/vagrant"

VAGRANT_PROVIDER=""
TEMP_DIRECTORY=""
TEMP_PUBLIC_KEY=""

log() {
    printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

fail() {
    printf '\nFehler: %s\n' "$1" >&2
    exit 1
}

cleanup() {
    if [[ -n "${TEMP_DIRECTORY}" && -d "${TEMP_DIRECTORY}" ]]; then
        rm -rf "${TEMP_DIRECTORY}"
    fi
}

trap cleanup EXIT

select_provider() {
    printf '\nVirtualisierungsanbieter auswählen:\n\n'
    printf '  1) Parallels Desktop\n'
    printf '  2) VirtualBox\n'
    printf '  3) VMware Fusion / Workstation\n\n'

    read -rp "Auswahl [1-3]: " provider_choice

    case "${provider_choice}" in
        1)
            VAGRANT_PROVIDER="parallels"
            ;;
        2)
            VAGRANT_PROVIDER="virtualbox"
            ;;
        3)
            VAGRANT_PROVIDER="vmware_desktop"
            ;;
        *)
            fail "Ungültige Auswahl."
            ;;
    esac
}

get_vm_ip() {
    local vm_name="$1"

    cd "${VAGRANT_DIR}"

    vagrant ssh "${vm_name}" \
        -c "hostname -I | awk '{print \$1}'" \
        2>/dev/null |
        tr -d '\r' |
        tail -n 1
}

install_public_key_on_vm() {
    local vm_name="$1"

    log "Installiere Ansible-Key auf ${vm_name}"

    cd "${VAGRANT_DIR}"

    vagrant upload \
        "${TEMP_PUBLIC_KEY}" \
        "/tmp/ansible_lab.pub" \
        "${vm_name}"

    vagrant ssh "${vm_name}" -c "
        set -e

        sudo install \
            -d \
            -m 700 \
            -o vagrant \
            -g vagrant \
            /home/vagrant/.ssh

        sudo touch /home/vagrant/.ssh/authorized_keys

        sudo sh -c \
            'cat /tmp/ansible_lab.pub >> /home/vagrant/.ssh/authorized_keys'

        sudo sort -u \
            /home/vagrant/.ssh/authorized_keys \
            -o /home/vagrant/.ssh/authorized_keys

        sudo chown \
            vagrant:vagrant \
            /home/vagrant/.ssh/authorized_keys

        sudo chmod 600 \
            /home/vagrant/.ssh/authorized_keys

        sudo rm -f /tmp/ansible_lab.pub
    "
}

command -v vagrant >/dev/null 2>&1 ||
    fail "Vagrant ist nicht installiert."

command -v scp >/dev/null 2>&1 ||
    fail "SCP ist nicht installiert."

[[ -f "${VAGRANT_DIR}/Vagrantfile" ]] ||
    fail "Vagrantfile wurde nicht gefunden."

select_provider

printf '\n============================================================\n'
printf 'Verbindung zum Ansible-Server\n'
printf '============================================================\n\n'

read -rp "IP-Adresse oder Hostname des Ansible-Servers: " ANSIBLE_SERVER

read -rp "SSH-Benutzer auf dem Ansible-Server: " \
    ANSIBLE_SERVER_USER

read -rp \
    "Pfad zum öffentlichen Key [~/.ssh/ansible_lab.pub]: " \
    ANSIBLE_PUBLIC_KEY_PATH

ANSIBLE_PUBLIC_KEY_PATH="${ANSIBLE_PUBLIC_KEY_PATH:-~/.ssh/ansible_lab.pub}"

[[ -n "${ANSIBLE_SERVER}" ]] ||
    fail "Die Adresse des Ansible-Servers fehlt."

[[ -n "${ANSIBLE_SERVER_USER}" ]] ||
    fail "Der Benutzer des Ansible-Servers fehlt."

TEMP_DIRECTORY="$(mktemp -d)"
TEMP_PUBLIC_KEY="${TEMP_DIRECTORY}/ansible_lab.pub"

log "Lade öffentlichen SSH-Key vom Ansible-Server"

scp \
    "${ANSIBLE_SERVER_USER}@${ANSIBLE_SERVER}:${ANSIBLE_PUBLIC_KEY_PATH}" \
    "${TEMP_PUBLIC_KEY}"

[[ -s "${TEMP_PUBLIC_KEY}" ]] ||
    fail "Der öffentliche Key konnte nicht geladen werden."

if ! grep -qE '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-)' "${TEMP_PUBLIC_KEY}"; then
    fail "Die Datei ist kein gültiger öffentlicher SSH-Key."
fi

log "Starte Vagrant-VMs mit ${VAGRANT_PROVIDER}"

cd "${VAGRANT_DIR}"

vagrant up --provider="${VAGRANT_PROVIDER}"

log "Prüfe VM-Status"

vagrant status

for vm_name in \
    web-server \
    app-server \
    db-server \
    monitoring-server
do
    install_public_key_on_vm "${vm_name}"
done

log "Ermittle IP-Adressen"

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

printf '\n============================================================\n'
printf 'Vagrant-VMs wurden erfolgreich vorbereitet.\n'
printf '============================================================\n'

printf '\nErmittelte IP-Adressen:\n'
printf '  web-server:        %s\n' "${WEB_IP}"
printf '  app-server:        %s\n' "${APP_IP}"
printf '  db-server:         %s\n' "${DB_IP}"
printf '  monitoring-server: %s\n' "${MONITORING_IP}"

printf '\nDiese IP-Adressen werden anschliessend im Script\n'
printf 'deploy-from-ansible-server.sh eingegeben.\n\n'