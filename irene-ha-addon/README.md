# irene-ha-addon
Аддон обертка для запуска [Ирины](https://github.com/janvarev/Irene-Voice-Assistant) в HA

## Как это работает?

Аддон выкачивает последнюю версию [Ирины](https://github.com/janvarev/Irene-Voice-Assistant) из Гитхаб репозитория и разворачивает ее в docker контейнере внутри экосистемы Home Assistant.
При развертывании происходит подключение `runva_webapi_docker.json` настроек Ирины как  `runva_webapi.json` и каталога `options_docker` как  `options`.



## Как отлаживать самостоятельно
Для отладки в локальном докере 
```
docker build --build-arg BUILD_FROM=ghcr.io/hassio-addons/debian-base:stable -t irene-ha-addon .
```

Для запуска под виндой контейнера в локальном докере
```
docker run --rm -it ^
  --name irene-ha-addon ^
  -p 5003:5003 ^
  -e HA_URL="http://ВАШ_IP_HA:8123/api" ^
  -e HA_TOKEN="ВАШ_ПРИВАТНЫЙ_ТОКЕН" ^
  -e LOG_LEVEL="debug" ^
  irene-ha-addon
```
