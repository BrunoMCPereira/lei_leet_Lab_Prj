import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import '../comunicacao.dart';
import 'registro_screen.dart'; // Importa a tela de registro de usuário
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final CommunicationHelper communicationHelper;

  LoginScreen({required this.communicationHelper});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    widget.communicationHelper.addOnLoginMessageReceived(_handleMessage);
  }

  @override
  void dispose() {
    widget.communicationHelper.removeOnLoginMessageReceived(_handleMessage);
    super.dispose();
  }

  void _handleMessage(String message) {
    developer.log('Mensagem recebida no LoginScreen: $message', name: 'LoginScreen');
    final decodedMessage = jsonDecode(message);
    if (decodedMessage['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(communicationHelper: widget.communicationHelper),
        ),
      );
    } else {
      setState(() {
        _errorMessage = decodedMessage['message'];
      });
    }
  }

  void _login() {
    final username = _usernameController.text;
    final password = _passwordController.text;

    developer.log('Tentativa de login com Username: $username', name: 'LoginScreen');

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, preencha todos os campos.';
      });
    } else if (username == 'admin' && password == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => UserRegistrationScreen(communicationHelper: widget.communicationHelper), // Navega para a tela de registro de usuário
        ),
      );
    } else {
      widget.communicationHelper.login(username, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image.asset(
                'assets/home_automation_leileet.png',
                width: 120,
                height: 120,
              ),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'Username'),
              ),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              SizedBox(height: 25),
              ElevatedButton(
                onPressed: _login,
                child: Text('Login'),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
