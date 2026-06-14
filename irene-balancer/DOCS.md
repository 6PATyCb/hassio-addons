## Как установить в HA?

Вам нужно подключить [мой репозиторий](https://github.com/6PATyCb/hassio-addons) в HA и из него уже будет доступна установка аддона.

## Как это работает?

Добавить описание!!!

## Как отлаживать самостоятельно?
Для отладки в локальном докере выкачайте проект и соберите Dockerfile
```
docker build --build-arg BUILD_FROM=ghcr.io/hassio-addons/base:19.0.0 -t irene-balancer .
```

Для запуска под виндой контейнера в локальном докере выполните команду:
```
docker run --rm -it ^
  --name irene-balancer ^
  -p 5013:5013 ^
  -e LISTEN_PORT="5013" ^
  -e TARGET_1="https://192.168.133.252:5003" ^
  -e TARGET_2="https://192.168.144.112:5003" ^
  -e DOMAIN="test.local" ^
  irene-balancer
```