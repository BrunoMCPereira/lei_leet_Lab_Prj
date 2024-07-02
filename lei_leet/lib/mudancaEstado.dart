import 'package:flutter/material.dart';

class DeviceState with ChangeNotifier {
  double _temperaturaAtual = 0.0;
  String _estadoIluminacao = 'Desligada';
  String _estadoEstores = 'Parado';
  String _estadoArCondicionado = 'Desligado';
  double _percentagemAbertura = 0.0;

  // Getters
  double get temperaturaAtual => _temperaturaAtual;
  String get estadoIluminacao => _estadoIluminacao;
  String get estadoArCondicionado => _estadoArCondicionado;
  String get estadoEstores => _estadoEstores;
  double get percentagemAbertura => _percentagemAbertura;

  // Setters
  set temperaturaAtual(double value) {
    _temperaturaAtual = value;
    notifyListeners();
  }

  set estadoIluminacao(String value) {
    _estadoIluminacao = value;
    notifyListeners();
  }

  set estadoArCondicionado(String value) {
    _estadoArCondicionado = value;
    notifyListeners();
  }

  set estadoEstores(String value) {
    _estadoEstores = value;
    notifyListeners();
  }

  set percentagemAbertura(double value) {
    _percentagemAbertura = value;
    notifyListeners();
  }

  // Limpar os estados
  void limparEstados() {
    _temperaturaAtual = 0.0;
    _estadoIluminacao = 'Desligada';
    _estadoEstores = 'Parado';
    _estadoArCondicionado = 'Desligado';
    _percentagemAbertura = 0.0;
    notifyListeners();
  }
}
