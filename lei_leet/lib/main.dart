import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/configuracao_screen.dart';
import 'comunicacao.dart';
import 'mudancaEstado.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? brokerAddress = prefs.getString('broker_address') ?? '192.168.1.239'; // IP padrão inicial

  DeviceState deviceState = DeviceState();
  CommunicationHelper communicationHelper = CommunicationHelper(brokerAddress, deviceState);

  bool connectivity = await communicationHelper.checkConnectivity();
  if (connectivity) {
    await communicationHelper.initializeMQTT();
    await communicationHelper.carregarParametrizacaoInicial(); // Carregar parametrização inicial
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => deviceState,
      child: MyApp(brokerAddress: connectivity ? brokerAddress : null, communicationHelper: communicationHelper),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String? brokerAddress;
  final CommunicationHelper communicationHelper;

  MyApp({this.brokerAddress, required this.communicationHelper});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LEI_LEET',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: brokerAddress != null 
          ? LoginScreen(communicationHelper: communicationHelper)
          : ConfiguracaoBrokerScreen(communicationHelper: communicationHelper),
    );
  }
}
