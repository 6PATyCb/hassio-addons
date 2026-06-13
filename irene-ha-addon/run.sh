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

# ПРОВЕРКА ПЕРВОГО ЗАПУСКА для options
# ls -A выводит все файлы (включая скрытые). Если вывод пустой, папка пуста.
if [ -z "$(ls -A /config/irene_options)" ]; then
    echo " Первый запуск: Копируем файлы по умолчанию для options..."
    # cp -a сохраняет права и структуру, -n запрещает перезапись существующих файлов
    # /. в конце пути означает "скопировать содержимое папки, а не саму папку"
    cp -an /app/irene/options/. /config/irene_options/
    cp -an /app/irene/plugins/. /config/irene_plugins/
    echo " Копирование options завершено..."
fi
# Удаляем оригинальные папки внутри образа, чтобы они не конфликтовали со ссылками
rm -rf /app/irene/options
rm -rf /app/irene/plugins

# Создаем символические ссылки
# Теперь приложение Irene будет думать, что работает с /app/irene/options,
# но на самом деле оно будет читать/писать в /config/irene_options
ln -s /config/irene_options /app/irene/options
ln -s /config/irene_plugins /app/irene/plugins

echo "=== Проверка созданных ссылок ==="
ls -la /app/irene/ | grep -E "options|plugins"


# === УСТАНОВКА ПОЛЬЗОВАТЕЛЬСКИХ ЗАВИСИМОСТЕЙ ===
echo "=== Проверка Python-зависимостей для плагинов ==="

# Создаем файл для пользовательских зависимостей, если его нет
CUSTOM_REQ="/config/irene_options/requirements-custom.txt"
if [ ! -f "$CUSTOM_REQ" ]; then
    echo "# Добавьте сюда зависимости для ваших кастомных плагинов (каждая с новой строки)" > "$CUSTOM_REQ"
    echo "# Например: requests==2.31.0" >> "$CUSTOM_REQ"
    echo "Создан файл для пользовательских зависимостей: $CUSTOM_REQ"
fi

# Устанавливаем базовые зависимости (из Git-репозитория) - быстро, т.к. уже установлены
pip3 install --break-system-packages -q -r /app/irene/requirements-docker.txt

# Устанавливаем пользовательские зависимости (если файл не пустой)
# grep -q проверяет, есть ли в файле что-то кроме комментариев и пустых строк
if grep -qE '^[^#[:space:]]' "$CUSTOM_REQ" 2>/dev/null; then
    echo "Найдены пользовательские зависимости. Устанавливаем..."
    pip3 install --break-system-packages -r "$CUSTOM_REQ"
else
    echo "Пользовательские зависимости не найдены. Пропускаем."
fi

# Переходим в папку с кодом
cd /app/irene

# Запуск приложения (ЗАМЕНИТЕ main.py на реальный файл входа в Irene, если нужно!)
exec python3 runva_webapi.py