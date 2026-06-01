#!/usr/bin/env bash
# Готовит тестовое окружение:
#   1. генерит одноразовый ssh-ключ (если его ещё нет) — он НЕ коммитится в git;
#   2. поднимает контейнер.
# Запуск: ./scripts/setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
KEY="${PROJECT_DIR}/docker/keys/id_ed25519"

mkdir -p "${PROJECT_DIR}/docker/keys"

if [[ ! -f "${KEY}" ]]; then
    echo "Генерю одноразовый тестовый ssh-ключ -> docker/keys/id_ed25519"
    ssh-keygen -t ed25519 -N "" -C "ansible-test-key DO-NOT-REUSE" -f "${KEY}"
else
    echo "Ключ уже есть: ${KEY}"
fi

echo "Поднимаю контейнер..."
cd "${PROJECT_DIR}"
docker compose up -d --build

echo
echo "Готово. Дальше:"
echo "  ansible-galaxy collection install -r requirements.yml"
echo "  ansible-playbook playbook.yml"
