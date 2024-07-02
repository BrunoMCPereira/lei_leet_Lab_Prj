import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../comunicacao.dart';

class ShuttersScreen extends StatefulWidget {
  final CommunicationHelper communicationHelper;

  ShuttersScreen({required this.communicationHelper});

  @override
  _ShuttersScreenState createState() => _ShuttersScreenState();
}

class _ShuttersScreenState extends State<ShuttersScreen> {
  bool isEditingParametrizacao = false;
  List<String> diasSemana = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.communicationHelper.solicitarParametrizacao('estores');
      _carregarDados(); // Carregar os dados após solicitar a parametrização
    });
  }

  void _carregarDados() {
    setState(() {
      isEditingParametrizacao = widget.communicationHelper.estoresParametrizacaoAtiva;
    });
    developer.log('Dados iniciais carregados', name: 'ShuttersScreen');
  }

  Future<void> alternarEstado() async {
    if (widget.communicationHelper.deviceState.estadoEstores == 'Parado') {
      widget.communicationHelper.subirEstores();
    } else {
      widget.communicationHelper.pararEstores();
    }
    await Future.delayed(Duration(milliseconds: 500));
    widget.communicationHelper.solicitarParametrizacao('estores');
    setState(() {}); // Atualiza o estado da interface
  }

  Future<void> _selecionarHoraAbrir(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: widget.communicationHelper.estoresHoraAbrir ?? TimeOfDay.now(),
    );
    if (picked != null && picked != widget.communicationHelper.estoresHoraAbrir) {
      setState(() {
        widget.communicationHelper.estoresHoraAbrir = picked;
      });
    }
  }

  Future<void> _selecionarHoraFechar(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: widget.communicationHelper.estoresHoraFechar ?? TimeOfDay.now(),
    );
    if (picked != null && picked != widget.communicationHelper.estoresHoraFechar) {
      setState(() {
        widget.communicationHelper.estoresHoraFechar = picked;
      });
    }
  }

  void _toggleDiaSelecionado(String dia) {
    setState(() {
      if (widget.communicationHelper.diasSelecionadosEstores.contains(dia)) {
        widget.communicationHelper.diasSelecionadosEstores.remove(dia);
      } else {
        widget.communicationHelper.diasSelecionadosEstores.add(dia);
      }
    });
  }

  Future<void> _atualizarParametrizacao() async {
    final parametros = {
      "estado": "ativo", // Sempre definir como "ativo" ao atualizar a parametrização
      "dias_semana": widget.communicationHelper.diasSelecionadosEstores,
      "horario": {
        "hora subir": widget.communicationHelper.estoresHoraAbrir != null
            ? '${widget.communicationHelper.estoresHoraAbrir!.hour.toString().padLeft(2, '0')}:${widget.communicationHelper.estoresHoraAbrir!.minute.toString().padLeft(2, '0')}'
            : null,
        "hora descer": widget.communicationHelper.estoresHoraFechar != null
            ? '${widget.communicationHelper.estoresHoraFechar!.hour.toString().padLeft(2, '0')}:${widget.communicationHelper.estoresHoraFechar!.minute.toString().padLeft(2, '0')}'
            : null,
      },
    };
    widget.communicationHelper.programarParametros("estores", parametros);
    await widget.communicationHelper.solicitarParametrizacao('estores'); // Solicitar novamente para garantir que os dados sejam atualizados
    _carregarDados(); // Atualiza os dados após a mudança de parametrização
    setState(() {}); // Garantir que a UI seja atualizada
  }

  Future<void> _cancelarParametrizacao() async {
    setState(() {
      widget.communicationHelper.estoresParametrizacaoAtiva = false;
      widget.communicationHelper.diasSelecionadosEstores.clear();
      widget.communicationHelper.estoresHoraAbrir = null;
      widget.communicationHelper.estoresHoraFechar = null;
    });
    final parametros = {
      "estado": "inativo",
      "metodo": "desabilitar",
      "dias_semana": [],
      "horario": {
        "hora subir": "inativo",
        "hora descer": "inativo",
      },
    };
    widget.communicationHelper.programarParametros("estores", parametros);
    _carregarDados(); // Atualiza os dados após o cancelamento de parametrização
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = widget.communicationHelper.deviceState;
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
                'Controle dos Estores',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              SizedBox(height: 16),
              ControlSection(
                title: 'Estores',
                statusText: 'Status: ${deviceState.estadoEstores}',
                onControl: alternarEstado,
                buttonColor: deviceState.estadoEstores == 'Parado' ? Colors.green : Colors.red,
                buttonText: deviceState.estadoEstores == 'Parado' ? 'Subir' : 'Parar',
              ),
              SizedBox(height: 16),
              if (widget.communicationHelper.estoresParametrizacaoAtiva) ...[
                Text(
                  'Agendamento Programado:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Wrap(
                  spacing: 10,
                  children: [
                    for (String dia in diasSemana)
                      ChoiceChip(
                        label: Text(dia),
                        selected: widget.communicationHelper.diasSelecionadosEstores.contains(dia),
                        onSelected: (bool selected) {
                          _toggleDiaSelecionado(dia);
                        },
                      ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text('Hora de abrir'),
                        ElevatedButton(
                          onPressed: () => _selecionarHoraAbrir(context),
                          child: Text(widget.communicationHelper.estoresHoraAbrir != null ? widget.communicationHelper.estoresHoraAbrir!.format(context) : 'Selecionar Hora'),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Hora de fechar'),
                        ElevatedButton(
                          onPressed: () => _selecionarHoraFechar(context),
                          child: Text(widget.communicationHelper.estoresHoraFechar != null ? widget.communicationHelper.estoresHoraFechar!.format(context) : 'Selecionar Hora'),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _atualizarParametrizacao,
                  child: Text('Atualizar Agendamento', style: TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _cancelarParametrizacao,
                  child: Text('Cancelar Agendamento', style: TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isEditingParametrizacao = true;
                    });
                  },
                  child: Text('Adicionar Parametrização', style: TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                if (isEditingParametrizacao) ...[
                  SizedBox(height: 16),
                  Text(
                    'Configurar Agendamento:',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      for (String dia in diasSemana)
                        ChoiceChip(
                          label: Text(dia),
                          selected: widget.communicationHelper.diasSelecionadosEstores.contains(dia),
                          onSelected: (bool selected) {
                            _toggleDiaSelecionado(dia);
                          },
                        ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text('Hora de abrir'),
                          ElevatedButton(
                            onPressed: () => _selecionarHoraAbrir(context),
                            child: Text(widget.communicationHelper.estoresHoraAbrir != null ? widget.communicationHelper.estoresHoraAbrir!.format(context) : 'Selecionar Hora'),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Hora de fechar'),
                          ElevatedButton(
                            onPressed: () => _selecionarHoraFechar(context),
                            child: Text(widget.communicationHelper.estoresHoraFechar != null ? widget.communicationHelper.estoresHoraFechar!.format(context) : 'Selecionar Hora'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _atualizarParametrizacao,
                    child: Text('Gravar Agendamento', style: TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ],
              SizedBox(height: 16),
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
  final Color buttonColor;
  final String buttonText;

  const ControlSection({
    required this.title,
    required this.statusText,
    required this.onControl,
    required this.buttonColor,
    required this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        width: 200,
        height: 160,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              SizedBox(height: 8),
              Text(
                statusText,
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: onControl,
                child: Text(buttonText, style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
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
