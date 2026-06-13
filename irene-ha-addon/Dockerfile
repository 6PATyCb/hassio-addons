ARG BUILD_FROM
FROM $BUILD_FROM

# 1. Устанавливаем Python и Git через apt (менеджер пакетов Debian)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    git \
    && rm -rf /var/lib/apt/lists/*

# 2. Рабочая директория
WORKDIR /app

# 3. Аргументы для клонирования
ARG IRENE_REPO_URL="https://github.com/janvarev/Irene-Voice-Assistant.git"
ARG IRENE_BRANCH="master"

# 4. Клонируем репозиторий
RUN git clone --branch ${IRENE_BRANCH} --depth 1 ${IRENE_REPO_URL} /app/irene

# 5. Исправляем опечатку в requirements
RUN if [ -f /app/irene/requirements-docker.txt ]; then \
      sed -i 's/~+/~=/' /app/irene/requirements-docker.txt; \
    fi

# 6. Устанавливаем зависимости Python
# Флаг --break-system-packages разрешает pip устанавливать пакеты глобально в Debian 12+
RUN if [ -f /app/irene/requirements-docker.txt ]; then \
      pip3 install --no-cache-dir --break-system-packages -r /app/irene/requirements-docker.txt; \
    elif [ -f /app/irene/requirements.txt ]; then \
      pip3 install --no-cache-dir --break-system-packages -r /app/irene/requirements.txt; \
    fi
	
# активируем файлы настроек Ирины адаптированные под докер	
RUN mv /app/irene/runva_webapi_docker.json /app/irene/runva_webapi.json && \
mv /app/irene/options_docker /app/irene/options

#RUN mv /app/irene/plugins /app/irene/plugins_orig && mv /app/irene/docker_plugins /app/irene/plugins

# Копируем скрипт запуска
COPY run.sh /

# КРИТИЧЕСКИ ВАЖНО: Конвертируем CRLF (Windows) в LF (Linux) и даем права на выполнение
RUN sed -i 's/\r$//' /run.sh && chmod a+x /run.sh

# КРИТИЧЕСКИ ВАЖНО: Отключаем s6-overlay. 
# Теперь контейнер будет просто выполнять /run.sh без лишних сервисов.
ENTRYPOINT []
CMD ["/run.sh"]