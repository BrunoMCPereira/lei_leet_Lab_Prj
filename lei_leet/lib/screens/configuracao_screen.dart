import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../comunicacao.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfiguracaoBrokerScreen extends StatefulWidget {
  final CommunicationHelper communicationHelper;

  ConfiguracaoBrokerScreen({required this.communicationHelper});

  @override
  _ConfiguracaoBrokerScreenState createState() => _ConfiguracaoBrokerScreenState();
}

class _ConfiguracaoBrokerScreenState extends State<ConfiguracaoBrokerScreen> {
  final TextEditingController _ultimaParteController = TextEditingController();
  bool _configurado = false;
  bool _tentandoConectar = false;

  @override
  void initState() {
    super.initState();
    _verificarConectividade();
  }

  Future<void> _verificarConectividade() async {
    developer.log('Verificando conectividade...', name: 'ConfiguracaoBrokerScreen');

    bool conectividadeOk = await widget.communicationHelper.checkConnectivity();

    if (conectividadeOk) {
      developer.log('Conectividade verificada com sucesso', name: 'ConfiguracaoBrokerScreen');
      setState(() {
        _configurado = true;
      });
    } else {
      developer.log('Conectividade falhou', name: 'ConfiguracaoBrokerScreen', error: true);
    }
  }

  Future<void> _confirmarConfiguracao() async {
    final ultimaParte = _ultimaParteController.text;
    final mascara = '192.168.1.$ultimaParte';
    developer.log('Confirmando configuração com máscara: $mascara', name: 'ConfiguracaoBrokerScreen');

    // Atualizar o brokerAddress e verificar conectividade após salvar a máscara
    setState(() {
      widget.communicationHelper.broker = mascara;
      _tentandoConectar = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('broker_address', mascara);

    bool connectivity = await widget.communicationHelper.checkConnectivity();
    if (connectivity) {
      await widget.communicationHelper.initializeMQTT();
      await widget.communicationHelper.carregarParametrizacaoInicial();
      setState(() {
        _configurado = true;
        _tentandoConectar = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen(communicationHelper: widget.communicationHelper)),
      );
    } else {
      setState(() {
        _tentandoConectar = false;
        _configurado = false;
      });
      developer.log('Conectividade falhou após configuração', name: 'ConfiguracaoBrokerScreen', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuração'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (!_configurado && !_tentandoConectar) ...[
              TextField(
                controller: _ultimaParteController,
                decoration: InputDecoration(labelText: 'Últimos dígitos do IP'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _confirmarConfiguracao,
                child: Text('Confirmar'),
              ),
              SizedBox(height: 20),
            ],
            if (_tentandoConectar) ...[
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Tentando conectar...'),
            ],
          ],
        ),
      ),
    );
  }
}
