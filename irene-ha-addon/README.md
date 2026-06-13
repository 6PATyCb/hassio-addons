# irene-ha-addon
Аддон обертка для запуска Ирины в HA

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
