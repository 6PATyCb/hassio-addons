# Home Assistant App: Irene-Voice-Assistant-balancer
Аддон балансировщик для перенаправления запросов STT и TTS нескольким копиям [Ирины](https://github.com/janvarev/Irene-Voice-Assistant).

![Supports amd64 Architecture][amd64-shield]

## Для чего он нужен?

Если вы используете Ирину для взаимодействия с HA в качестве [STT](https://github.com/6PATyCb/irene_stt) и [TTS](https://github.com/6PATyCb/irene_tts), то с помощью этого балансировшика вы можете перенаправлять запросы на другую копию Ирины, если она доступна.

Приведу свой пример: у меня в домашней сети есть миниПК с HA и Ириной1 запущенной внутри HA. Внутри HA развернуты также [STT](https://github.com/6PATyCb/irene_stt) и [TTS](https://github.com/6PATyCb/irene_tts).
Также на моем основном ПК у меня развернута Ирина2, которая работает не постоянно, но имеет мощные модели ИИ для STT и TTS.
Я развернул балансировщик внутри HA и настроил его так, что Ирина2 является основной ссылкой, а Ирина1 - резервной. Плагины STT и TTS в HA ссылаются на балансировщик, что позволяеть обрабатывать вызовы на Ирине2, если она доступна, а если недоступна, то на Ирине1.

При желании, данный балансировщик можно запустить просто в докер контейнере без HA.

[Документация](https://github.com/6PATyCb/hassio-addons/blob/main/irene-balancer/DOCS.md)

[Irene-Voice-Assistant]: https://github.com/janvarev/Irene-Voice-Assistant
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg


