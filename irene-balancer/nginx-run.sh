#!/usr/bin/env bash
set -e

# ==============================================================================
# УМНАЯ ФУНКЦИЯ ЧТЕНИЯ ПЕРЕМЕННЫХ
# Приоритет: 1. ENV Docker -> 2. s6-overlay -> 3. HA options.json -> 4. Дефолт
# ==============================================================================
get_var() {
    local var_name_upper=$1
    local var_name_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    local default_val=$2
    local val=""
    
    # 1. Ищем в переменных окружения (Docker run -e)
    val="${!var_name_upper:-}"
    
    # 2. Ищем в хранилище s6-overlay
    if [[ -z "$val" && -f "/run/s6/container_environment/$var_name_upper" ]]; then
        val=$(cat "/run/s6/container_environment/$var_name_upper" 2>/dev/null)
    fi
    
    # 3. Ищем в файле настроек Home Assistant (/data/options.json)
    if [[ -z "$val" && -f "/data/options.json" ]]; then
        val=$(jq -r ".$var_name_lower // empty" /data/options.json 2>/dev/null)
    fi
    
    # 4. Если нигде не нашли, возвращаем дефолт
    if [[ -z "$val" || "$val" == "null" ]]; then
        echo "$default_val"
    else
        echo "$val"
    fi
}

# Функция для парсинга URL (убираем http:// или https://, оставляем host:port)
parse_url() {
    echo "$1" | sed -E 's|^https?://||'
}

# ==============================================================================
# 1. Чтение переменных (с безопасными дефолтами из вашего config.yaml)
# ==============================================================================
TARGET_1=$(get_var "TARGET_1" "https://192.168.1.10:5003")
TARGET_2=$(get_var "TARGET_2" "https://192.168.1.11:5003")
DOMAIN=$(get_var "DOMAIN" "home.local")
LISTEN_PORT=$(get_var "LISTEN_PORT" "5013")

# ==============================================================================
# 2. Парсинг URL для Nginx (разделяем протокол и адрес)
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
# 4. Генерация конфига Nginx
# ==============================================================================
TEMPLATE_FILE="/etc/nginx/templates/default.conf.template"
TARGET_FILE="/etc/nginx/http.d/default.conf"

# Удаляем стандартные конфиги Alpine
rm -f /etc/nginx/http.d/*.conf
cp "$TEMPLATE_FILE" "$TARGET_FILE"

# Подставляем переменные
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