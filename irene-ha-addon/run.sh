#!/bin/bash

# 1. Определяем URL и Токен для Home Assistant
if [ -n "${SUPERVISOR_TOKEN:-}" ]; then
    export HA_TOKEN="${SUPERVISOR_TOKEN}"
    export HA_URL="http://supervisor/core/api"
else
    export HA_TOKEN="${HA_TOKEN:-}"
    export HA_URL="${HA_URL:-http://host.docker.internal:8123/api}"
fi

echo "VOSK_MODEL_PATH=${VOSK_MODEL_PATH}"

# 2. Читаем настройки из options.json
export LOG_LEVEL="info"
if [ -f /data/options.json ]; then
    export LOG_LEVEL=$(python3 -c "import json; print(json.load(open('/data/options.json')).get('log_level', 'info'))" 2>/dev/null || echo "info")
fi

if [ -n "${LOG_LEVEL_ENV:-}" ]; then
    export LOG_LEVEL="${LOG_LEVEL_ENV}"
fi

echo "=== Irene Addon Starting ==="
echo "HA API URL: $HA_URL"
echo "LOG_LEVEL: $LOG_LEVEL"

# === ИНИЦИАЛИЗАЦИЯ ПРИЛОЖЕНИЯ В /config ===
IRENE_DATA_DIR="/config/irene"

# Создаем корневую папку, если её нет
mkdir -p "$IRENE_DATA_DIR"

# Проверяем, пуста ли папка (признак самого первого запуска)
if [ -z "$(ls -A "$IRENE_DATA_DIR")" ]; then
    echo "[INFO] Первый запуск: Копируем всё приложение из образа в /config/irene..."
    # Копируем ВСЁ содержимое /app/irene в /config/irene
    # Флаг -a сохраняет все права, ссылки и структуру
    cp -a /app/irene/. "$IRENE_DATA_DIR/"
    echo "[INFO] Копирование приложения завершено."
else
    echo "[INFO] Приложение уже развернуто в /config/irene. Пропускаем копирование."
fi

# === НАСТРОЙКА PYTHON ОКРУЖЕНИЯ ===
# Теперь всё (код, плагины, temp, кэш, venv) лежит в одной файловой системе /config
VENV_DIR="$IRENE_DATA_DIR/venv"

if [ ! -d "$VENV_DIR" ]; then
    echo "[INFO] Создаем виртуальное окружение в /config/irene/venv..."
    python3 -m venv --system-site-packages "$VENV_DIR"
else
    echo "[INFO] Виртуальное окружение найдено и используется."
fi

# Активируем venv
source "$VENV_DIR/bin/activate"

# === УСТАНОВКА ЗАВИСИМОСТЕЙ ===
echo "=== Проверка Python-зависимостей ==="

# Обновляем pip
pip install -q --upgrade pip

# Устанавливаем базовые зависимости из файла, который теперь лежит в /config/irene
# Pip автоматически пропустит уже установленные пакеты и докачает только новые (при обновлении аддона)
pip install -q -r "$IRENE_DATA_DIR/requirements-docker.txt"

# Файл для пользовательских зависимостей
CUSTOM_REQ="$IRENE_DATA_DIR/requirements-custom.txt"
if [ ! -f "$CUSTOM_REQ" ]; then
    echo "# Добавьте сюда зависимости для ваших кастомных плагинов (каждая с новой строки)" > "$CUSTOM_REQ"
    echo "# Например: requests==2.31.0" >> "$CUSTOM_REQ"
    echo "[INFO] Создан файл для пользовательских зависимостей: $CUSTOM_REQ"
fi

if grep -qE '^[^#[:space:]]' "$CUSTOM_REQ" 2>/dev/null; then
    echo "[INFO] Найдены пользовательские зависимости. Устанавливаем/обновляем..."
    pip install -r "$CUSTOM_REQ"
else
    echo "[INFO] Пользовательские зависимости не найдены. Пропускаем."
fi

# Переходим в папку с кодом (теперь это постоянная папка на хосте)
cd "$IRENE_DATA_DIR"

# Запуск приложения
exec python3 runva_webapi.py