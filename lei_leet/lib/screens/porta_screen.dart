import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import '../comunicacao.dart';

class DoorScreen extends StatelessWidget {
  final CommunicationHelper communicationHelper;

  DoorScreen({required this.communicationHelper});

  void _abrirPorta() {
    developer.log('Enviando comando para abrir a porta', name: 'DoorScreen');
    communicationHelper.publish('app/porta', jsonEncode({"acao": "abrir"}));
  }

  void _fecharPorta() {
    developer.log('Enviando comando para fechar a porta', name: 'DoorScreen');
    communicationHelper.publish('app/porta', jsonEncode({"acao": "fechar"}));
  }

  void _trancarPorta() {
    developer.log('Enviando comando para trancar a porta', name: 'DoorScreen');
    communicationHelper.publish('app/porta', jsonEncode({"acao": "trancar"}));
  }

  void _destrancarPorta() {
    developer.log('Enviando comando para destrancar a porta', name: 'DoorScreen');
    communicationHelper.publish('app/porta', jsonEncode({"acao": "destrancar"}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Controle da Porta',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Controle da Porta',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _abrirPorta,
                child: Text('Abrir Porta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fecharPorta,
                child: Text('Fechar Porta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _trancarPorta,
                child: Text('Trancar Porta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _destrancarPorta,
                child: Text('Destrancar Porta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Voltar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
