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

# === ИНИЦИАЛИЗАЦИЯ ПАПОК ===
# Новая структура: все данные в /config/irene/
IRENE_DATA_DIR="/config/irene"

# Гарантированно создаем корневую папку и подпапки
mkdir -p "$IRENE_DATA_DIR/options"
mkdir -p "$IRENE_DATA_DIR/plugins"

# МИГРАЦИЯ: Переносим данные из старых папок (если они есть)
if [ -d "/config/irene_options" ] && [ ! -L "/config/irene_options" ]; then
    echo "[INFO] Обнаружены старые данные в /config/irene_options. Переносим в новую структуру..."
    cp -an /config/irene_options/. "$IRENE_DATA_DIR/options/" 2>/dev/null || true
    rm -rf /config/irene_options
fi

if [ -d "/config/irene_plugins" ] && [ ! -L "/config/irene_plugins" ]; then
    echo "[INFO] Обнаружены старые данные в /config/irene_plugins. Переносим в новую структуру..."
    cp -an /config/irene_plugins/. "$IRENE_DATA_DIR/plugins/" 2>/dev/null || true
    rm -rf /config/irene_plugins
fi

# ПРОВЕРКА ПЕРВОГО ЗАПУСКА для options
if [ -z "$(ls -A "$IRENE_DATA_DIR/options")" ]; then
    echo "[INFO] Первый запуск: Копируем файлы по умолчанию для options..."
    cp -an /app/irene/options/. "$IRENE_DATA_DIR/options/"
    echo "[INFO] Копирование options завершено."
else
    echo "[INFO] Папка options уже содержит файлы. Пропускаем копирование."
fi

# ПРОВЕРКА ПЕРВОГО ЗАПУСКА для plugins
if [ -z "$(ls -A "$IRENE_DATA_DIR/plugins")" ]; then
    echo "[INFO] Первый запуск: Копируем файлы по умолчанию для plugins..."
    cp -an /app/irene/plugins/. "$IRENE_DATA_DIR/plugins/"
    echo "[INFO] Копирование plugins завершено."
else
    echo "[INFO] Папка plugins уже содержит файлы. Пропускаем копирование."
fi

# Удаляем оригинальные папки внутри образа, чтобы они не конфликтовали со ссылками
rm -rf /app/irene/options
rm -rf /app/irene/plugins

# Создаем символические ссылки
ln -s "$IRENE_DATA_DIR/options" /app/irene/options
ln -s "$IRENE_DATA_DIR/plugins" /app/irene/plugins

echo "=== Проверка созданных ссылок ==="
ls -la /app/irene/ | grep -E "options|plugins"

# === ПОСТОЯННОЕ ВИРТУАЛЬНОЕ ОКРУЖЕНИЕ ===
echo "=== Настройка Python-окружения ==="

VENV_DIR="$IRENE_DATA_DIR/venv"

# Создаем venv только при ПЕРВОМ запуске
# Флаг --system-site-packages позволяет venv видеть пакеты из Docker-образа
if [ ! -d "$VENV_DIR" ]; then
    echo "[INFO] Первый запуск: Создаем виртуальное окружение (это займет время)..."
    python3 -m venv --system-site-packages "$VENV_DIR"
else
    echo "[INFO] Виртуальное окружение уже существует. Используем его."
fi

# Активируем venv
# Теперь все команды pip будут работать внутри него
source "$VENV_DIR/bin/activate"

# === УСТАНОВКА ЗАВИСИМОСТЕЙ ===
echo "=== Проверка Python-зависимостей ==="

# Устанавливаем базовые зависимости (из Git-репозитория)
# Pip увидит, что они уже есть в system-site-packages, и пропустит их
pip install -q --upgrade pip
pip install -q -r /app/irene/requirements-docker.txt

# Создаем файл для пользовательских зависимостей, если его нет
CUSTOM_REQ="$IRENE_DATA_DIR/requirements-custom.txt"
if [ ! -f "$CUSTOM_REQ" ]; then
    echo "# Добавьте сюда зависимости для ваших кастомных плагинов (каждая с новой строки)" > "$CUSTOM_REQ"
    echo "# Например: requests==2.31.0" >> "$CUSTOM_REQ"
    echo "[INFO] Создан файл для пользовательских зависимостей: $CUSTOM_REQ"
fi

# Устанавливаем пользовательские зависимости (если файл не пустой)
# grep -q проверяет, есть ли в файле что-то кроме комментариев и пустых строк
if grep -qE '^[^#[:space:]]' "$CUSTOM_REQ" 2>/dev/null; then
    echo "[INFO] Найдены пользовательские зависимости. Устанавливаем/обновляем..."
    pip install -r "$CUSTOM_REQ"
else
    echo "[INFO] Пользовательские зависимости не найдены. Пропускаем."
fi

# Переходим в папку с кодом
cd /app/irene

# Запуск приложения
exec python3 runva_webapi.py