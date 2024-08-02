# Projeto de Automação com Shelly e MQTT

Este projeto tem como objetivo controlar dispositivos Shelly utilizando MQTT. A aplicação é composta por um script Python que se conecta ao broker MQTT para enviar comandos aos dispositivos Shelly e uma aplicação Flutter que serve como interface de usuário para controlar esses dispositivos remotamente.
Estrutura do Projeto

    mqtt_control.py: Script Python que conecta-se ao broker MQTT e envia comandos para os dispositivos Shelly.
    helpers: Diretório que contém o helper do Firestore usado na aplicação Flutter.
    app_flutter: Diretório da aplicação Flutter que serve como interface de usuário.

# Requisitos

    Python 3.x
    Flask
    Paho MQTT
    Raspberry Pi (ou outro dispositivo para rodar o script Python)
    Dispositivo Shelly
    Broker MQTT (por exemplo, Mosquitto)
    Flutter SDK
    Firebase (para o Firestore)
