#!/usr/bin/env bash
# Скачивает реальную подборку картинок из Google Drive в files/images/.
# Подборка из задания: https://drive.google.com/file/d/1L9hsq9ZFB5VbXYJ3kEKH47x9nhxxZEnI
#
# gdrive-линки приватные/с квотами -> надёжно дёргать их из самого Ansible-прогона нельзя
# (ломает идемпотентность и offline-прогон). Поэтому качаем заранее этим скриптом,
# а роль static уже раскладывает то, что лежит в files/images/.
#
# Требует: pip install gdown
set -euo pipefail

FILE_ID="1L9hsq9ZFB5VbXYJ3kEKH47x9nhxxZEnI"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="${SCRIPT_DIR}/../files/images"
ARCHIVE="${DEST_DIR}/_collection_download"

mkdir -p "${DEST_DIR}"

if ! command -v gdown >/dev/null 2>&1; then
    echo "gdown не найден. Установи: pip install gdown" >&2
    exit 1
fi

echo "Качаю подборку из Google Drive (file id: ${FILE_ID})..."
gdown "${FILE_ID}" -O "${ARCHIVE}"

# Подборка приходит архивом - распаковываем по типу.
case "$(file -b --mime-type "${ARCHIVE}")" in
    application/zip)        unzip -o "${ARCHIVE}" -d "${DEST_DIR}" ;;
    application/gzip|application/x-gzip) tar -xzf "${ARCHIVE}" -C "${DEST_DIR}" ;;
    *) echo "Неизвестный формат - проверь ${ARCHIVE} вручную" >&2 ;;
esac

rm -f "${ARCHIVE}"
echo "Готово. Картинки в ${DEST_DIR}"
