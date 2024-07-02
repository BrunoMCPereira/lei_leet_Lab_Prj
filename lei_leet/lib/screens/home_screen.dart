import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../comunicacao.dart';
import 'login_screen.dart';
import 'temperatura_screen.dart';
import 'iluminacao_screen.dart';
import 'alterar_senha_screen.dart';
import '../mudancaEstado.dart'; // Importando a classe DeviceState

class HomeScreen extends StatefulWidget {
  final CommunicationHelper communicationHelper;

  HomeScreen({required this.communicationHelper});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'A SUA CASA',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ControlSection(
                      title: 'Temperatura',
                      statusText: '${deviceState.temperaturaAtual} °C', // Usando DeviceState
                      onControl: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TemperatureScreen(
                              communicationHelper: widget.communicationHelper,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ControlSection(
                      title: 'Iluminação',
                      statusText: deviceState.estadoIluminacao, // Usando DeviceState
                      onControl: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LightingScreen(
                              communicationHelper: widget.communicationHelper,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AlterarSenhaScreen(
                        communicationHelper: widget.communicationHelper,
                      ),
                    ),
                  );
                },
                child: Text('Alterar Senha', style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoginScreen(
                        communicationHelper: widget.communicationHelper,
                      ),
                    ),
                    (route) => false,
                  );
                },
                child: Text('Sair', style: TextStyle(color: Colors.white, fontSize: 16)),
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
              'Estado: $statusText',
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
