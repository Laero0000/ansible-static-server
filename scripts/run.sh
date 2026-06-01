#!/usr/bin/env bash
# Запуск плейбука из WSL, когда проект лежит на диске Windows (/mnt/c/...).
#
# Зачем нужен: такая папка world-writable, и Ansible из соображений безопасности
# игнорирует лежащий в ней ansible.cfg целиком. Вместе с ним теряются inventory,
# host_key_checking, ssh_args и формат вывода. Плюс ssh отвергает приватный ключ
# на /mnt/c, потому что там у файла всегда права 0777 ("UNPROTECTED PRIVATE KEY").
#
# Скрипт восстанавливает все эти настройки через переменные окружения (их Ansible
# читает всегда, world-writable их не блокирует) и кладёт копию ключа в Linux-FS
# с правами 0600, где они держатся.
#
# Аргументы прокидываются в ansible-playbook, например:
#   ./scripts/run.sh                 # обычный прогон
#   ./scripts/run.sh --tags static   # только заливка картинок
#   ./scripts/run.sh --check         # dry-run
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_KEY="${PROJECT_DIR}/docker/keys/id_ed25519"

if [[ ! -f "${SRC_KEY}" ]]; then
    echo "Ключ ${SRC_KEY} не найден. Сначала запусти ./scripts/setup.sh" >&2
    exit 1
fi

# Копия ключа в домашке (Linux-FS) с корректными правами — на /mnt/c chmod не липнет.
SAFE_KEY="${HOME}/.ssh/static-server-test-key"
mkdir -p "${HOME}/.ssh"
cp -f "${SRC_KEY}" "${SAFE_KEY}"
chmod 600 "${SAFE_KEY}"

# Дублируем настройки ansible.cfg, который world-writable-папка заставляет игнорировать.
export ANSIBLE_INVENTORY="${PROJECT_DIR}/inventory/hosts.ini"
export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_CALLBACK_RESULT_FORMAT=yaml
export ANSIBLE_SSH_ARGS='-o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

# Путь к ключу задаётся через -e, а не env: в inventory есть host-переменная
# ansible_ssh_private_key_file, и она перебила бы переменную окружения. extra-vars
# имеют наивысший приоритет и гарантированно укажут на копию с правами 0600.
cd "${PROJECT_DIR}"
exec ansible-playbook playbook.yml -e "ansible_ssh_private_key_file=${SAFE_KEY}" "$@"
