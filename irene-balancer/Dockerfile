ARG BUILD_FROM
FROM $BUILD_FROM

# ==============================================================================
# 1. Установка Nginx
# ==============================================================================
RUN apk add --no-cache nginx

# ==============================================================================
# 2. Копирование шаблона и скрипта запуска
# ==============================================================================
# Копируем шаблон конфига
COPY default.conf.template /etc/nginx/templates/default.conf.template

# Копируем шаблон страницы статуса
COPY status.html.template /etc/nginx/templates/status.html.template

# Копируем скрипт запуска (он же выполняет роль init)
COPY nginx-run.sh /etc/s6-overlay/s6-rc.d/nginx/run

# Конвертируем CRLF (Windows) в LF (Linux) и даем права на выполнение
RUN sed -i 's/\r$//' /etc/s6-overlay/s6-rc.d/nginx/run && chmod a+x /etc/s6-overlay/s6-rc.d/nginx/run

# Настраиваем структуру сервиса s6-overlay
RUN mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d && \
    echo "longrun" > /etc/s6-overlay/s6-rc.d/nginx/type && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/nginx && \
    chmod +x /etc/s6-overlay/s6-rc.d/nginx/run

# Копируем тестовые сертификаты 
# (Внимание: см. примечание ниже про папку /ssl в Home Assistant)
COPY localhost.crt /ssl/localhost.crt
COPY localhost.key /ssl/localhost.key

# ==============================================================================
# 3. Патчи для standalone-режима (отключаем обращение к Supervisor API)
# ==============================================================================
RUN mv /package/admin/s6-overlay/etc/s6-rc/scripts/base-addon-log-level \
        /package/admin/s6-overlay/etc/s6-rc/scripts/base-addon-log-level.orig && \
    printf '#!/usr/bin/env bash\n\
if [[ -z "${SUPERVISOR_TOKEN:-${HASSIO_TOKEN:-}}" ]] || ! getent hosts supervisor > /dev/null 2>&1; then\n\
    echo "[INFO] Standalone mode detected. Skipping Supervisor API interaction (log-level)."\n\
    exit 0\n\
fi\n\
exec /package/admin/s6-overlay/etc/s6-rc/scripts/base-addon-log-level.orig "$@"\n' \
    > /package/admin/s6-overlay/etc/s6-rc/scripts/base-addon-log-level && \
    chmod +x /package/admin/s6-overlay/etc/s6-rc/scripts/base-addon-log-level

RUN mv /package/admin/s6-overlay/etc/s6-rc/scripts/base-addon-banner \
        /package/admin/s6-overlay/etc/s6-rc/scripts/base-addon-banner.orig && \
    printf '#!/usr/bin/env bash\n\
if [[ -z "${SUPERVISOR_TOKEN:-${HASSIO_TOKEN:-}}" ]] || ! getent hosts supervisor > /dev/null 2>&1; then\n\
    echo "[INFO] Standalone mode detected. Skipping Supervisor API interaction (banner)."\n\
    exit 0\n\
fi\n\
exec /package/admin/s6-overlay/etc/s6-rc/scripts/base-addon-banner.orig "$@"\n' \
    > /package/admin/s6-overlay/etc/s6-rc/scripts/base-addon-banner && \
    chmod +x /package/admin/s6-overlay/etc/s6-rc/scripts/base-addon-banner