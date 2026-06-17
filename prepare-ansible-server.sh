#!/usr/bin/env bash

set -Eeuo pipefail

# ==============================================================================
# Vorbereitung des Ansible-Servers
#
# Das Script:
#   1. aktualisiert den Server
#   2. installiert Git, Ansible, SSH und weitere Werkzeuge
#   3. erstellt einen SSH-Key für das Ansible-Lab
#
# Das Script wird nur auf dem Ansible-Server ausgeführt.
# ==============================================================================

DEPLOYMENT_USER="${SUDO_USER:-${USER}}"
DEPLOYMENT_HOME="$(getent passwd "${DEPLOYMENT_USER}" | cut -d: -f6)"

ANSIBLE_SSH_DIR="${DEPLOYMENT_HOME}/.ssh"
ANSIBLE_SSH_KEY="${ANSIBLE_SSH_DIR}/ansible_lab"
ANSIBLE_SSH_PUBLIC_KEY="${ANSIBLE_SSH_KEY}.pub"

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

if ! command -v apt-get >/dev/null 2>&1; then
    fail "Dieses Script unterstützt aktuell nur Ubuntu oder Debian."
fi

if [[ -z "${DEPLOYMENT_HOME}" || ! -d "${DEPLOYMENT_HOME}" ]]; then
    fail "Das Home-Verzeichnis konnte nicht ermittelt werden."
fi

export DEBIAN_FRONTEND=noninteractive

log "Aktualisiere Paketlisten"

apt-get update

log "Installiere verfügbare Aktualisierungen"

apt-get upgrade -y
apt-get autoremove -y

log "Installiere benötigte Programme"

apt-get install -y \
    ansible \
    ca-certificates \
    curl \
    git \
    gnupg \
    openssh-client \
    python3 \
    python3-apt \
    python3-pip \
    python3-venv \
    software-properties-common \
    wget

log "Erstelle SSH-Verzeichnis"

install \
    -d \
    -m 700 \
    -o "${DEPLOYMENT_USER}" \
    -g "${DEPLOYMENT_USER}" \
    "${ANSIBLE_SSH_DIR}"

if [[ ! -f "${ANSIBLE_SSH_KEY}" ]]; then
    log "Erstelle Ansible-SSH-Key"

    run_as_deployment_user ssh-keygen \
        -t ed25519 \
        -f "${ANSIBLE_SSH_KEY}" \
        -N "" \
        -C "ansible-monitoring-lab"
else
    log "Ansible-SSH-Key existiert bereits"
fi

[[ -f "${ANSIBLE_SSH_KEY}" ]] ||
    fail "Der private SSH-Key wurde nicht erstellt."

[[ -f "${ANSIBLE_SSH_PUBLIC_KEY}" ]] ||
    fail "Der öffentliche SSH-Key wurde nicht erstellt."

chown \
    "${DEPLOYMENT_USER}:${DEPLOYMENT_USER}" \
    "${ANSIBLE_SSH_KEY}" \
    "${ANSIBLE_SSH_PUBLIC_KEY}"

chmod 600 "${ANSIBLE_SSH_KEY}"
chmod 644 "${ANSIBLE_SSH_PUBLIC_KEY}"

printf '\n============================================================\n'
printf 'Ansible-Server wurde erfolgreich vorbereitet.\n'
printf '============================================================\n'

printf '\nPrivater SSH-Key:\n'
printf '  %s\n' "${ANSIBLE_SSH_KEY}"

printf '\nÖffentlicher SSH-Key:\n'
printf '  %s\n\n' "${ANSIBLE_SSH_PUBLIC_KEY}"

printf 'Der öffentliche Key wird anschliessend vom lokalen\n'
printf 'start-vagrant-only.sh auf die VMs übertragen.\n\n'

printf 'Öffentlicher Key:\n\n'
cat "${ANSIBLE_SSH_PUBLIC_KEY}"
printf '\n'