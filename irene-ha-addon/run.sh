#!/bin/bash

# 1. Определяем URL и Токен для Home Assistant
# В HA Supervisor сам создает переменную SUPERVISOR_TOKEN при старте аддона.
# Локально мы передадим токен через переменную HA_TOKEN.
if [ -n "${SUPERVISOR_TOKEN:-}" ]; then
    export HA_TOKEN="${SUPERVISOR_TOKEN}"
    export HA_URL="http://supervisor/core/api"
else
    export HA_TOKEN="${HA_TOKEN:-}"
    export HA_URL="${HA_URL:-http://host.docker.internal:8123/api}"
fi

# 2. Читаем настройки из options.json (если он есть, т.е. мы в HA)
# Используем Python для парсинга JSON, чтобы не зависеть от jq
export LOG_LEVEL="info"
if [ -f /data/options.json ]; then
    export LOG_LEVEL=$(python3 -c "import json; print(json.load(open('/data/options.json')).get('log_level', 'info'))" 2>/dev/null || echo "info")
fi

# Если переменная окружения LOG_LEVEL_ENV передана явно (локально), она имеет приоритет
if [ -n "${LOG_LEVEL_ENV:-}" ]; then
    export LOG_LEVEL="${LOG_LEVEL_ENV}"
fi

echo "=== Irene Addon Starting ==="
echo "HA API URL: $HA_URL"
echo "LOG_LEVEL: $LOG_LEVEL"

# Переходим в папку с кодом
cd /app/irene

# Запуск приложения (ЗАМЕНИТЕ main.py на реальный файл входа в Irene, если нужно!)
exec python3 runva_webapi.py