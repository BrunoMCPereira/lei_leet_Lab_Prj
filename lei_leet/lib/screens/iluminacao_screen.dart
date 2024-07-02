import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Importando o Provider
import 'estores_screen.dart';
import 'luzes_screen.dart';
import '../comunicacao.dart'; // Certifique-se de que o caminho está correto
import '../mudancaEstado.dart'; // Importando a classe DeviceState

class LightingScreen extends StatelessWidget {
  final CommunicationHelper communicationHelper;

  LightingScreen({required this.communicationHelper});

  @override
  Widget build(BuildContext context) {
    final deviceState = Provider.of<DeviceState>(context); // Acessando o DeviceState usando o Provider

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'LEI_LEET',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
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
                'Controle de Iluminação',
                style: TextStyle(color: Colors.blue,fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ControlSection(
                      title: 'Luz',
                      statusText: deviceState.estadoIluminacao, // Usando DeviceState
                      onControl: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => LightsScreen(communicationHelper: communicationHelper)),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ControlSection(
                      title: 'Estores',
                      statusText: deviceState.estadoEstores, // Usando DeviceState
                      onControl: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ShuttersScreen(communicationHelper: communicationHelper)),
                        );
                      },
                    ),
                  ),
                ],
              ),
              Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Voltar', style: TextStyle(color: Colors.white, fontSize: 16)),
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

class ControlSection extends StatelessWidget {
  final String title;
  final String statusText;
  final VoidCallback onControl;

  const ControlSection({
    required this.title,
    required this.statusText,
    required this.onControl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Status: $statusText',
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: onControl,
              child: Text('Controlar', style: TextStyle(color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
