#!/usr/bin/env bash

set -Eeuo pipefail

# ==============================================================================
# Deployment von einem separaten Ansible-Server
#
# Voraussetzungen:
#   - prepare-ansible-server.sh wurde ausgeführt
#   - die Ziel-VMs wurden mit start-vagrant-only.sh erstellt
#   - der öffentliche Ansible-Key ist auf allen VMs installiert
#
# Das Script:
#   1. klont oder aktualisiert das Repository über HTTPS
#   2. fragt die IP-Adressen der Ziel-VMs ab
#   3. erstellt das Ansible-Inventory
#   4. prüft die SSH-Verbindungen
#   5. führt das Playbook aus
#   6. prüft die Services
# ==============================================================================

REPOSITORY_URL="https://github.com/bromag/Ansible-based-Server-Monitoring-Deployment.git"
REPOSITORY_BRANCH="main"

DEPLOYMENT_USER="${SUDO_USER:-${USER}}"
DEPLOYMENT_HOME="$(getent passwd "${DEPLOYMENT_USER}" | cut -d: -f6)"

INSTALL_DIR="${DEPLOYMENT_HOME}/Ansible-based-Server-Monitoring-Deployment"

ANSIBLE_SSH_KEY="${DEPLOYMENT_HOME}/.ssh/ansible_lab"

log() {
    printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

fail() {
    printf '\nFehler: %s\n' "$1" >&2
    exit 1
}

run_as_deployment_user() {
    sudo -u "${DEPLOYMENT_USER}" \
        HOME="${DEPLOYMENT_HOME}" \
        "$@"
}

if [[ "${EUID}" -ne 0 ]]; then
    fail "Das Script muss mit sudo gestartet werden."
fi

command -v git >/dev/null 2>&1 ||
    fail "Git ist nicht installiert. Führe prepare-ansible-server.sh aus."

command -v ansible >/dev/null 2>&1 ||
    fail "Ansible ist nicht installiert. Führe prepare-ansible-server.sh aus."

[[ -f "${ANSIBLE_SSH_KEY}" ]] ||
    fail "Ansible-SSH-Key fehlt. Führe prepare-ansible-server.sh aus."

chmod 600 "${ANSIBLE_SSH_KEY}"

if [[ -d "${INSTALL_DIR}/.git" ]]; then
    log "Aktualisiere vorhandenes Repository"

    run_as_deployment_user git \
        -C "${INSTALL_DIR}" \
        fetch origin

    run_as_deployment_user git \
        -C "${INSTALL_DIR}" \
        checkout "${REPOSITORY_BRANCH}"

    run_as_deployment_user git \
        -C "${INSTALL_DIR}" \
        pull --ff-only origin "${REPOSITORY_BRANCH}"
else
    log "Klone Repository über HTTPS"

    run_as_deployment_user git clone \
        --branch "${REPOSITORY_BRANCH}" \
        --single-branch \
        "${REPOSITORY_URL}" \
        "${INSTALL_DIR}"
fi

ANSIBLE_DIR="${INSTALL_DIR}/ansible"
INVENTORY_FILE="${ANSIBLE_DIR}/inventory/hosts.ini"
PLAYBOOK_FILE="${ANSIBLE_DIR}/site.yml"

[[ -f "${PLAYBOOK_FILE}" ]] ||
    fail "Playbook wurde nicht gefunden: ${PLAYBOOK_FILE}"

printf '\n============================================================\n'
printf 'Konfiguration der Zielserver\n'
printf '============================================================\n\n'

read -rp "IP-Adresse des Webservers: " WEB_IP
read -rp "IP-Adresse des App-Servers: " APP_IP
read -rp "IP-Adresse des Datenbankservers: " DB_IP
read -rp "IP-Adresse des Monitoring-Servers: " MONITORING_IP

read -rp "SSH-Benutzer der Zielserver [vagrant]: " SSH_USER
SSH_USER="${SSH_USER:-vagrant}"

[[ -n "${WEB_IP}" ]] ||
    fail "Die IP-Adresse des Webservers fehlt."

[[ -n "${APP_IP}" ]] ||
    fail "Die IP-Adresse des App-Servers fehlt."

[[ -n "${DB_IP}" ]] ||
    fail "Die IP-Adresse des Datenbankservers fehlt."

[[ -n "${MONITORING_IP}" ]] ||
    fail "Die IP-Adresse des Monitoring-Servers fehlt."

mkdir -p "$(dirname "${INVENTORY_FILE}")"

log "Erstelle Ansible-Inventory"

cat > "${INVENTORY_FILE}" <<EOF
[web]
web-server ansible_host=${WEB_IP}

[app]
app-server ansible_host=${APP_IP}

[db]
db-server ansible_host=${DB_IP}

[monitoring]
monitoring-server ansible_host=${MONITORING_IP}

[all:vars]
ansible_user=${SSH_USER}
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_private_key_file=${ANSIBLE_SSH_KEY}
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

chown "${DEPLOYMENT_USER}:${DEPLOYMENT_USER}" "${INVENTORY_FILE}"
chmod 600 "${INVENTORY_FILE}"

log "Installiere benötigte Ansible Collection"

run_as_deployment_user ansible-galaxy collection install ansible.mysql

cd "${ANSIBLE_DIR}"

log "Prüfe Inventory"

run_as_deployment_user ansible-inventory \
    --inventory "${INVENTORY_FILE}" \
    --graph

log "Prüfe Playbook-Syntax"

run_as_deployment_user ansible-playbook \
    --inventory "${INVENTORY_FILE}" \
    "${PLAYBOOK_FILE}" \
    --syntax-check

log "Teste SSH-Verbindungen"

run_as_deployment_user ansible \
    --inventory "${INVENTORY_FILE}" \
    all \
    --module-name ping

log "Starte vollständiges Deployment"

run_as_deployment_user ansible-playbook \
    --inventory "${INVENTORY_FILE}" \
    "${PLAYBOOK_FILE}"

log "Prüfe Services"

for service_check in \
    "web-server nginx" \
    "app-server python-app" \
    "db-server mariadb" \
    "monitoring-server prometheus" \
    "monitoring-server grafana-server"
do
    host="${service_check%% *}"
    service="${service_check##* }"

    run_as_deployment_user ansible \
        --inventory "${INVENTORY_FILE}" \
        "${host}" \
        --become \
        --module-name command \
        --args "systemctl is-active ${service}"
done

printf '\n============================================================\n'
printf 'Deployment erfolgreich abgeschlossen.\n'
printf '============================================================\n'

printf '\nWebapplikation:\n'
printf '  http://%s\n' "${WEB_IP}"

printf '\nPrometheus:\n'
printf '  http://%s:9090\n' "${MONITORING_IP}"

printf '\nGrafana:\n'
printf '  http://%s:3000\n\n' "${MONITORING_IP}"