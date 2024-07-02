import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;
import 'package:mqtt_client/mqtt_server_client.dart' as mqtt;
import 'mudancaEstado.dart'; // Importe a classe DeviceState

class CommunicationHelper {
  late String broker;
  final int port = 2224;
  mqtt.MqttServerClient? client;
  final List<Function(String)> _loginCallbacks = [];
  final DeviceState deviceState;

  bool luzesParametrizacaoAtiva = false;
  List<String> diasSelecionadosLuzes = [];
  TimeOfDay? luzesHoraLigar;
  TimeOfDay? luzesHoraDesligar;

  bool estoresParametrizacaoAtiva = false;
  List<String> diasSelecionadosEstores = [];
  TimeOfDay? estoresHoraAbrir;
  TimeOfDay? estoresHoraFechar;

  bool arCondicionadoParametrizacaoAtiva = false;
  List<String> diasSelecionadosArCondicionado = [];
  TimeOfDay? arCondicionadoHoraLigar;
  TimeOfDay? arCondicionadoHoraDesligar;
  double arCondicionadoTemperaturaDefinida = 23.0;
  double arCondicionadotemperaturaPretendidaParametrizacao = 23.0;

  CommunicationHelper(this.broker, this.deviceState);

  Future<void> initializeMQTT() async {
    developer.log('Inicializando MQTT...', name: 'CommunicationHelper');

    client = mqtt.MqttServerClient(broker, 'client-id-${DateTime.now().millisecondsSinceEpoch}')
      ..port = port
      ..keepAlivePeriod = 20
      ..onDisconnected = onDisconnected
      ..onConnected = onConnected
      ..onSubscribed = onSubscribed
      ..logging(on: true);

    final connMessage = mqtt.MqttConnectMessage()
        .withClientIdentifier('client-id-${DateTime.now().millisecondsSinceEpoch}')
        .withWillQos(mqtt.MqttQos.atLeastOnce)
        .startClean()
        .withWillTopic('willtopic')
        .withWillMessage('My Will message')
        .withWillRetain();

    client!.connectionMessage = connMessage;

    try {
      developer.log('Tentando conectar ao broker MQTT...', name: 'CommunicationHelper');
      await client!.connect();
      developer.log('MQTT Conectado', name: 'CommunicationHelper');
      subscribe('app/fluxo');
      subscribe('resposta/app/fluxo');
      subscribe('resposta/parametrizacao/app/fluxo');
      subscribe('inicio/parametrizacao/app/fluxo');
      subscribe('envio/parametrizacao/app/fluxo');
      subscribe('estado/app/fluxo'); // Assinando o novo tópico de estado

      // Carregar parametrizações iniciais após a conexão bem-sucedida
      carregarParametrizacaoInicial();
    } catch (e) {
      developer.log('Falha na conexão MQTT: $e', name: 'CommunicationHelper', error: e);
      reconnect();
    }

    client!.updates?.listen((List<mqtt.MqttReceivedMessage<mqtt.MqttMessage>> c) {
      final mqtt.MqttPublishMessage recMess = c[0].payload as mqtt.MqttPublishMessage;
      final String message = mqtt.MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      developer.log('Mensagem recebida: $message', name: 'CommunicationHelper');

      final decodedMessage = jsonDecode(message);

      // Log do tópico e filtragem de mensagens de login
      developer.log('Tópico: ${c[0].topic}', name: 'CommunicationHelper');
      if (c[0].topic == 'resposta/app/fluxo' && decodedMessage.containsKey('success')) {
        for (var callback in _loginCallbacks) {
          developer.log('Encaminhando mensagem de login para callback: $message', name: 'CommunicationHelper');
          callback(message);
        }
      }

      // Processamento de mensagens de parametrização
      if (c[0].topic == 'resposta/parametrizacao/app/fluxo') {
        _processarMensagemParametrizacao(decodedMessage);
      } else if (c[0].topic == 'estado/app/fluxo') {
        _processarMensagemEstado(decodedMessage);
      } else {
        // Processamento de outras mensagens
        if (decodedMessage['informacao'] == 'temperatura') {
          developer.log('Processando mensagem de temperatura: ${decodedMessage['valor monotorizado']}', name: 'CommunicationHelper');
          deviceState.temperaturaAtual = decodedMessage['valor monotorizado'].toDouble();
        } else if (decodedMessage['dispositivo'] == 'luzes' && decodedMessage['estado'] != null) {
          developer.log('Processando mensagem de luzes: ${decodedMessage['estado']}', name: 'CommunicationHelper');
          deviceState.estadoIluminacao = decodedMessage['estado'] == 'ligado' ? 'Ligada' : 'Desligada';
        } else if (decodedMessage['dispositivo'] == 'estores' && decodedMessage['estado'] != null) {
          developer.log('Processando mensagem de estores: ${decodedMessage['estado']}', name: 'CommunicationHelper');
          var estadoEstore = decodedMessage['estado'];
          if (estadoEstore is String) {
            if (estadoEstore == 'subindo') {
              deviceState.estadoEstores = 'A Subir';
            } else if (estadoEstore == 'descendo') {
              deviceState.estadoEstores = 'A Descer';
            } else {
              deviceState.estadoEstores = 'Parado';
            }
          } else if (estadoEstore is Map) {
            if (estadoEstore['funcionamento'] == 'a subir') {
              deviceState.estadoEstores = 'A Subir';
            } else if (estadoEstore['funcionamento'] == 'a descer') {
              deviceState.estadoEstores = 'A Descer';
            } else {
              deviceState.estadoEstores = 'Parado';
            }
            deviceState.percentagemAbertura = estadoEstore['percentagem_abertura']?.toDouble() ?? deviceState.percentagemAbertura;
          }
        } else if (decodedMessage['dispositivo'] == 'ar_condicionado' && decodedMessage['estado'] != null) {
          developer.log('Processando mensagem de ar condicionado: ${decodedMessage['estado']}', name: 'CommunicationHelper');
          deviceState.estadoArCondicionado = decodedMessage['estado'] == 'ligado' ? 'Ligado' : 'Desligado';
        }
      }
    });
  }

  Future<void> carregarParametrizacaoInicial() async {
    solicitarParametrizacao('luzes');
    solicitarParametrizacao('estores');
    solicitarParametrizacao('ar_condicionado');
  }

  void reconnect() async {
    await Future.delayed(Duration(seconds: 5));
    await initializeMQTT();
  }

  Future<bool> checkConnectivity() async {
    developer.log('Verificando conectibilidade com o broker $broker:$port...', name: 'CommunicationHelper');

    try {
      final result = await InternetAddress.lookup(broker);
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        developer.log('IP do broker resolvido: ${result[0].address}', name: 'CommunicationHelper');

        Socket socket = await Socket.connect(broker, port, timeout: Duration(seconds: 5));
        socket.destroy();
        developer.log('Conectividade verificada com sucesso', name: 'CommunicationHelper');
        return true;
      } else {
        developer.log('Falha ao resolver o IP do broker', name: 'CommunicationHelper');
      }
    } catch (e) {
      developer.log('Falha na verificação de conectividade: $e', name: 'CommunicationHelper', error: e);
    }

    return false;
  }

  void subscribe(String topic) {
    if (client == null) {
      developer.log('Erro: cliente MQTT é nulo', name: 'CommunicationHelper');
      return;
    }
    client!.subscribe(topic, mqtt.MqttQos.atLeastOnce);
    developer.log('Subscrito ao tópico: $topic', name: 'CommunicationHelper');
  }

  void publish(String topic, String message) {
    if (client == null) {
      developer.log('Erro: cliente MQTT é nulo', name: 'CommunicationHelper');
      return;
    }

    final builder = mqtt.MqttClientPayloadBuilder();
    builder.addString(message);
    if (builder.payload == null) {
      developer.log('Erro: payload do MQTT é nulo', name: 'CommunicationHelper');
      return;
    }

    client!.publishMessage(topic, mqtt.MqttQos.atLeastOnce, builder.payload!);
    developer.log('Mensagem publicada no tópico $topic: $message', name: 'CommunicationHelper');
  }

  void addOnLoginMessageReceived(Function(String) callback) {
    _loginCallbacks.add(callback);
    developer.log('Callback de mensagem de login recebido configurado', name: 'CommunicationHelper');
  }

  void removeOnLoginMessageReceived(Function(String) callback) {
    _loginCallbacks.remove(callback);
    developer.log('Callback de mensagem de login recebido removido', name: 'CommunicationHelper');
  }

  void onSubscribed(String topic) {
    developer.log('Subscrito ao tópico: $topic', name: 'CommunicationHelper');
  }

  void onDisconnected() {
    developer.log('MQTT Desconectado', name: 'CommunicationHelper');
    if (client?.connectionStatus?.returnCode == mqtt.MqttConnectReturnCode.noneSpecified) {
      developer.log('MQTT Desconectado inesperadamente', name: 'CommunicationHelper');
    }
  }

  void onConnected() {
    developer.log('MQTT Conectado', name: 'CommunicationHelper');
  }

  void disconnect() {
    if (client != null) {
      client!.disconnect();
      developer.log('MQTT Desconectado manualmente', name: 'CommunicationHelper');
    }
  }

  bool isConnected() {
    return client != null && client!.connectionStatus!.state == mqtt.MqttConnectionState.connected;
  }

  void login(String username, String password) {
    final Map<String, String> credentials = {
      "instrucao": "login",
      "username": username,
      "password": password,
    };
    publish('app/fluxo', jsonEncode(credentials));
  }

  void ligarLuz() {
    final message = {
      "instrucao": "Ordem",
      "parametros": {
        "luzes": "ligar"
      }
    };
    publish('app/fluxo', jsonEncode(message));
  }

  void desligarLuz() {
    final message = {
      "instrucao": "Ordem",
      "parametros": {
        "luzes": "desligar"
      }
    };
    publish('app/fluxo', jsonEncode(message));
  }

  void subirEstores() {
    final message = {
      "instrucao": "Ordem",
      "parametros": {
        "estores": "subir"
      }
    };
    publish('app/fluxo', jsonEncode(message));
  }

  void descerEstores() {
    final message = {
      "instrucao": "Ordem",
      "parametros": {
        "estores": "descer"
      }
    };
    publish('app/fluxo', jsonEncode(message));
  }

  void pararEstores() {
    final message = {
      "instrucao": "Ordem",
      "parametros": {
        "estores": "parar"
      }
    };
    publish('app/fluxo', jsonEncode(message));
  }

  void ligarArCondicionado() {
    final message = {
      "instrucao": "Ordem",
      "parametros": {
        "ar_condicionado": "ligar"
      }
    };
    publish('app/fluxo', jsonEncode(message));
  }

  void desligarArCondicionado() {
    final message = {
      "instrucao": "Ordem",
      "parametros": {
        "ar_condicionado": "desligar"
      }
    };
    publish('app/fluxo', jsonEncode(message));
  }

  Future<void> programarParametros(String dispositivo, Map<String, dynamic> parametros) async {
    // Simula o envio dos dados para o backend
    await Future.delayed(Duration(seconds: 1));
    final message = {
      "instrucao": "Programar",
      "metodo": "habilitar",
      "parametros": {
        "dispositivo": dispositivo,
        "parametros": parametros
      }
    };
    publish('envio/parametrizacao/app/fluxo', jsonEncode(message));
  }

  Future<void> solicitarParametrizacao(String dispositivo) async {
  // Simula o envio dos dados para o backend
    await Future.delayed(Duration(seconds: 1));
    final message = {
      "instrucao": "SolicitarParametrizacao",
      "dispositivo": dispositivo,
    };
    publish('inicio/parametrizacao/app/fluxo', jsonEncode(message));
    developer.log('Solicitação de parametrização enviada: $dispositivo', name: 'CommunicationHelper');
  }

  void adicionarUser(String username, String password) {
    final message = {
      "instrucao": "addUser",
      "parametros": {
        "username": username,
        "password": password
      }
    };
    publish('app/fluxo', jsonEncode(message));
  }

  void removerUser(String username) {
    final message = {
      "instrucao": "removerUser",
      "parametros": {
        "username": username,
      }
    };
    publish('app/fluxo', jsonEncode(message));
  }

  void solicitarParametros(String dispositivo) {
    final message = {
      "instrucao": "RecuperarParametros",
      "parametros": {
        "dispositivo": dispositivo,
      }
    };
    publish('app/fluxo', jsonEncode(message));
  }

  void alterarSenha(String currentPassword, String newPassword) {
    final Map<String, String> senhaInfo = {
      "instrucao": "alterarSenha",
      "currentPassword": currentPassword,
      "newPassword": newPassword,
    };
    publish('app/fluxo', jsonEncode(senhaInfo));
    developer.log('Solicitação de alteração de senha enviada', name: 'CommunicationHelper');
  }

  void _processarMensagemParametrizacao(Map<String, dynamic> decodedMessage) {
    // Processar mensagens de parametrização recebidas
    if (decodedMessage['dispositivo'] == 'luzes') {
      if (decodedMessage['parametrizacao']['estado'] == 'ativo') {
        luzesParametrizacaoAtiva = true;
        diasSelecionadosLuzes = List<String>.from(decodedMessage['parametrizacao']['dias_semana']);
        luzesHoraLigar = TimeOfDay(
          hour: int.parse(decodedMessage['parametrizacao']['horario']['ligar'].split(':')[0]),
          minute: int.parse(decodedMessage['parametrizacao']['horario']['ligar'].split(':')[1]),
        );
        luzesHoraDesligar = TimeOfDay(
          hour: int.parse(decodedMessage['parametrizacao']['horario']['desligar'].split(':')[0]),
          minute: int.parse(decodedMessage['parametrizacao']['horario']['desligar'].split(':')[1]),
        );
      } else {
        luzesParametrizacaoAtiva = false;
      }
    } else if (decodedMessage['dispositivo'] == 'estores') {
      if (decodedMessage['parametrizacao']['estado'] == 'ativo') {
        estoresParametrizacaoAtiva = true;
        diasSelecionadosEstores = List<String>.from(decodedMessage['parametrizacao']['dias_semana']);
        estoresHoraAbrir = TimeOfDay(
          hour: int.parse(decodedMessage['parametrizacao']['horario']['hora subir'].split(':')[0]),
          minute: int.parse(decodedMessage['parametrizacao']['horario']['hora subir'].split(':')[1]),
        );
        estoresHoraFechar = TimeOfDay(
          hour: int.parse(decodedMessage['parametrizacao']['horario']['hora descer'].split(':')[0]),
          minute: int.parse(decodedMessage['parametrizacao']['horario']['hora descer'].split(':')[1]),
        );
      } else {
        estoresParametrizacaoAtiva = false;
      }
    } else if (decodedMessage['dispositivo'] == 'ar_condicionado') {
      if (decodedMessage['parametrizacao']['estado'] == 'ativo') {
        arCondicionadoParametrizacaoAtiva = true;
        diasSelecionadosArCondicionado = List<String>.from(decodedMessage['parametrizacao']['dias_semana']);
        arCondicionadoHoraLigar = TimeOfDay(
          hour: int.parse(decodedMessage['parametrizacao']['horario']['ligar'].split(':')[0]),
          minute: int.parse(decodedMessage['parametrizacao']['horario']['ligar'].split(':')[1]),
        );
        arCondicionadoHoraDesligar = TimeOfDay(
          hour: int.parse(decodedMessage['parametrizacao']['horario']['desligar'].split(':')[0]),
          minute: int.parse(decodedMessage['parametrizacao']['horario']['desligar'].split(':')[1]),
        );
        arCondicionadotemperaturaPretendidaParametrizacao = decodedMessage['parametrizacao']['temperatura'].toDouble();
      } else {
        arCondicionadoParametrizacaoAtiva = false;
      }
    }
  }

  void definirTemperatura(double temperatura) {
    // Aqui você pode implementar a lógica para enviar a temperatura pretendida ao servidor
    final parametros = {
      "estado": "ativo",  // Ou "inativo" dependendo do contexto
      "temperatura": temperatura,
    };
    programarParametros("ar_condicionado", parametros);
  }

  

  void _processarMensagemEstado(Map<String, dynamic> decodedMessage) {
    // Atualizar variáveis do provider com base na mensagem recebida no tópico de estado
    final dispositivo = decodedMessage['dispositivo'];
    final estado = decodedMessage['estado'];

    if (dispositivo == 'luzes') {
      deviceState.estadoIluminacao = estado == 'ligado' ? 'Ligada' : 'Desligada';
    } else if (dispositivo == 'estores') {
      if (estado == 'subindo') {
        deviceState.estadoEstores = 'A Subir';
      } else if (estado == 'descendo') {
        deviceState.estadoEstores = 'A Descer';
      } else {
        deviceState.estadoEstores = 'Parado';
      }
      if (decodedMessage.containsKey('percentagem_abertura')) {
        deviceState.percentagemAbertura = decodedMessage['percentagem_abertura'].toDouble();
      }
    } else if (dispositivo == 'ar_condicionado') {
      deviceState.estadoArCondicionado = estado == 'ligado' ? 'Ligado' : 'Desligado';
    }
  }
}
