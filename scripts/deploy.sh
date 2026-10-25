#!/usr/bin/env bash
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=1
            ;;
        *)
            echo "Неизвестный аргумент: $arg" >&2
            exit 1
            ;;
    esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Ошибка: не удалось определить корень git-репозитория" >&2
    exit 1
}

LOCAL_DIR="${REPO_ROOT}/site/"

if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: отсутствует файл ${LOCAL_DIR}index.html" >&2
    exit 1
fi

if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незафиксированные изменения" >&2
    exit 1
fi

RSYNC_SSH='ssh -o BatchMode=yes -o ConnectTimeout=5'
RSYNC_OPTS=(-avz --delete --chmod=D755,F644 -e "$RSYNC_SSH")

if [[ $DRY_RUN -eq 1 ]]; then
    rsync "${RSYNC_OPTS[@]}" --dry-run "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"
    echo "Dry-run для коммита: $(git -C "$REPO_ROOT" rev-parse --short HEAD)"
    exit 0
fi

rsync "${RSYNC_OPTS[@]}" "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

if ! curl -fsS --cacert "$CA_CERT" --max-time 10 "$SITE_URL" >/dev/null; then
    echo "Ошибка: ресурс ${SITE_URL} недоступен или сертификат не прошёл проверку" >&2
    exit 1
fi

echo "Доставлен коммит: $(git -C "$REPO_ROOT" rev-parse --short HEAD)"
exit 0