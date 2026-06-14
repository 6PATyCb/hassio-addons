#!/usr/bin/env bash
set -e

# ==============================================================================
# Функция для чтения переменных из s6-overlay или Docker
# ==============================================================================
get_env() {
    local var_name=$1
    local default_val=$2
    local val="${!var_name:-$(cat /run/s6/container_environment/$var_name 2>/dev/null)}"
    echo "${val:-$default_val}"
}

# Функция для парсинга URL (убираем http:// или https://, оставляем host:port)
parse_url() {
    echo "$1" | sed -E 's|^https?://||'
}

# ==============================================================================
# 1. Чтение переменных
# ==============================================================================
TARGET_1=$(get_env "TARGET_1" "http://primary.local:8080")
TARGET_2=$(get_env "TARGET_2" "http://backup.local:8080")
DOMAIN=$(get_env "DOMAIN" "localhost")
LISTEN_PORT=$(get_env "LISTEN_PORT" "443")

# Если есть SUPERVISOR_TOKEN, пробуем прочитать из HA config
if [[ -n "$(get_env "SUPERVISOR_TOKEN" "")" ]]; then
    if [[ "$TARGET_1" == "http://primary.local:8080" ]]; then
        TARGET_1=$(bashio::config "target_1" "http://primary.local:8080" 2>/dev/null || echo "http://primary.local:8080")
    fi
    if [[ "$TARGET_2" == "http://backup.local:8080" ]]; then
        TARGET_2=$(bashio::config "target_2" "http://backup.local:8080" 2>/dev/null || echo "http://backup.local:8080")
    fi
    if [[ "$DOMAIN" == "localhost" ]]; then
        DOMAIN=$(bashio::config "domain" "localhost" 2>/dev/null || echo "localhost")
    fi
fi

# ==============================================================================
# 2. Парсинг URL для Nginx
# ==============================================================================
BACKEND_1_HOST_PORT=$(parse_url "$TARGET_1")
BACKEND_2_HOST_PORT=$(parse_url "$TARGET_2")

if [[ "$TARGET_1" == https://* ]]; then
    BACKEND_SCHEME="https"
else
    BACKEND_SCHEME="http"
fi

# ==============================================================================
# 3. Жесткая проверка SSL
# ==============================================================================
if [[ ! -f /ssl/localhost.crt || ! -f /ssl/localhost.key ]]; then
    echo "[FATAL] SSL certificates (localhost.crt / localhost.key) not found in /ssl/!"
    exit 1
fi

echo "[INFO] Generating Nginx config for domain: ${DOMAIN}"
echo "[INFO] Nginx will listen on port: ${LISTEN_PORT}"
echo "[INFO] Primary target: ${TARGET_1} (parsed: ${BACKEND_1_HOST_PORT})"
echo "[INFO] Backup target: ${TARGET_2} (parsed: ${BACKEND_2_HOST_PORT})"
echo "[INFO] Backend scheme: ${BACKEND_SCHEME}"

# ==============================================================================
# 4. Генерация конфига
# ==============================================================================
TEMPLATE_FILE="/etc/nginx/templates/default.conf.template"
TARGET_FILE="/etc/nginx/http.d/default.conf"

rm -f /etc/nginx/http.d/*.conf
cp "$TEMPLATE_FILE" "$TARGET_FILE"

sed -i "s|@@BACKEND_1_HOST_PORT@@|${BACKEND_1_HOST_PORT}|g" "$TARGET_FILE"
sed -i "s|@@BACKEND_2_HOST_PORT@@|${BACKEND_2_HOST_PORT}|g" "$TARGET_FILE"
sed -i "s|@@BACKEND_SCHEME@@|${BACKEND_SCHEME}|g" "$TARGET_FILE"
sed -i "s|@@DOMAIN@@|${DOMAIN}|g" "$TARGET_FILE"
sed -i "s|@@LISTEN_PORT@@|${LISTEN_PORT}|g" "$TARGET_FILE"

echo "[INFO] Nginx config generated successfully."

# ==============================================================================
# 5. Генерация страницы статуса
# ==============================================================================
STATUS_TEMPLATE="/etc/nginx/templates/status.html.template"
STATUS_FILE="/usr/share/nginx/html/status.html"

if [[ -f "$STATUS_TEMPLATE" ]]; then
    mkdir -p /usr/share/nginx/html
    cp "$STATUS_TEMPLATE" "$STATUS_FILE"
    sed -i "s|@@BACKEND_1@@|${TARGET_1}|g" "$STATUS_FILE"
    sed -i "s|@@BACKEND_2@@|${TARGET_2}|g" "$STATUS_FILE"
    echo "[INFO] Status page generated at /status.html"
fi

# ==============================================================================
# 6. Запуск Nginx
# ==============================================================================
mkdir -p /run/nginx
exec /usr/sbin/nginx -g "daemon off;"