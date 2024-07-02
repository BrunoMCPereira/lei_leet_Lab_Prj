import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../comunicacao.dart';

class AlterarSenhaScreen extends StatefulWidget {
  final CommunicationHelper communicationHelper;

  AlterarSenhaScreen({required this.communicationHelper});

  @override
  _AlterarSenhaScreenState createState() => _AlterarSenhaScreenState();
}

class _AlterarSenhaScreenState extends State<AlterarSenhaScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController _currentPasswordController = TextEditingController();
  TextEditingController _newPasswordController = TextEditingController();

  late CommunicationHelper communicationHelper;

  @override
  void initState() {
    super.initState();
    communicationHelper = widget.communicationHelper;
  }

  void _alterarSenha() {
    if (_formKey.currentState!.validate()) {
      String currentPassword = _currentPasswordController.text;
      String newPassword = _newPasswordController.text;

      communicationHelper.alterarSenha(currentPassword, newPassword);
      developer.log('Solicitação de alteração de senha enviada: $newPassword', name: 'AlterarSenhaScreen');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solicitação de alteração de senha enviada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _currentPasswordController,
                decoration: InputDecoration(labelText: 'Senha Atual'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira a senha atual';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _newPasswordController,
                decoration: InputDecoration(labelText: 'Nova Senha'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira a nova senha';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _alterarSenha,
                child: Text('Alterar Senha'),
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
