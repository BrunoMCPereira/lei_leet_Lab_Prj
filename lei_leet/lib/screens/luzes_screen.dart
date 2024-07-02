import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../comunicacao.dart';
import '../mudancaEstado.dart';

class LightsScreen extends StatefulWidget {
  final CommunicationHelper communicationHelper;

  LightsScreen({required this.communicationHelper});

  @override
  _LightsScreenState createState() => _LightsScreenState();
}

class _LightsScreenState extends State<LightsScreen> {
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
      widget.communicationHelper.solicitarParametrizacao('luzes');
      _carregarDados(); // Carregar os dados após solicitar a parametrização
    });
  }

  void _carregarDados() {
    setState(() {
      isEditingParametrizacao = widget.communicationHelper.luzesParametrizacaoAtiva;
      // Atualizar os dias selecionados para os dias em português
      widget.communicationHelper.diasSelecionadosLuzes = widget.communicationHelper.diasSelecionadosLuzes;
    });
    developer.log('Dados iniciais carregados', name: 'LightsScreen');
  }

  Future<void> alternarEstado() async {
    if (widget.communicationHelper.deviceState.estadoIluminacao == 'Desligada') {
      widget.communicationHelper.ligarLuz();
    } else {
      widget.communicationHelper.desligarLuz();
    }
    await Future.delayed(Duration(milliseconds: 500));
    widget.communicationHelper.solicitarParametrizacao('luzes');
    setState(() {}); // Atualiza o estado da interface
  }

  Future<void> _selecionarHoraLigar(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: widget.communicationHelper.luzesHoraLigar ?? TimeOfDay.now(),
    );
    if (picked != null && picked != widget.communicationHelper.luzesHoraLigar) {
      setState(() {
        widget.communicationHelper.luzesHoraLigar = picked;
      });
    }
  }

  Future<void> _selecionarHoraDesligar(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: widget.communicationHelper.luzesHoraDesligar ?? TimeOfDay.now(),
    );
    if (picked != null && picked != widget.communicationHelper.luzesHoraDesligar) {
      setState(() {
        widget.communicationHelper.luzesHoraDesligar = picked;
      });
    }
  }

  void _toggleDiaSelecionado(String dia) {
    setState(() {
      if (widget.communicationHelper.diasSelecionadosLuzes.contains(dia)) {
        widget.communicationHelper.diasSelecionadosLuzes.remove(dia);
      } else {
        widget.communicationHelper.diasSelecionadosLuzes.add(dia);
      }
    });
  }

  Future<void> _atualizarParametrizacao() async {
    final parametros = {
      "estado": "ativo", // Sempre definir como "ativo" ao atualizar a parametrização
      "dias_semana": widget.communicationHelper.diasSelecionadosLuzes,
      "horario": {
        "ligar": widget.communicationHelper.luzesHoraLigar != null
            ? '${widget.communicationHelper.luzesHoraLigar!.hour.toString().padLeft(2, '0')}:${widget.communicationHelper.luzesHoraLigar!.minute.toString().padLeft(2, '0')}'
            : null,
        "desligar": widget.communicationHelper.luzesHoraDesligar != null
            ? '${widget.communicationHelper.luzesHoraDesligar!.hour.toString().padLeft(2, '0')}:${widget.communicationHelper.luzesHoraDesligar!.minute.toString().padLeft(2, '0')}'
            : null,
      },
    };
    widget.communicationHelper.programarParametros("luzes", parametros);
    await widget.communicationHelper.solicitarParametrizacao('luzes'); // Solicitar novamente para garantir que os dados sejam atualizados
    _carregarDados(); // Atualiza os dados após a mudança de parametrização
    setState(() {}); // Garantir que a UI seja atualizada
  }

  Future<void> _cancelarParametrizacao() async {
    setState(() {
      widget.communicationHelper.luzesParametrizacaoAtiva = false;
      widget.communicationHelper.diasSelecionadosLuzes.clear();
      widget.communicationHelper.luzesHoraLigar = null;
      widget.communicationHelper.luzesHoraDesligar = null;
    });
    final parametros = {
      "estado": "inativo",
      "modelo" : "dasabilitar",
      "dias_semana": [],
      "horario": {
        "ligar": "inativo",
        "desligar": "inativo",
      },
    };
    widget.communicationHelper.programarParametros("luzes", parametros);
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
                'Controle das Luzes',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              SizedBox(height: 16),
              ControlSection(
                title: 'Luzes',
                statusText: 'Status: ${deviceState.estadoIluminacao}',
                onControl: alternarEstado,
                buttonColor: deviceState.estadoIluminacao == 'Desligada' ? Colors.green : Colors.red,
                buttonText: deviceState.estadoIluminacao == 'Desligada' ? 'Ligar' : 'Desligar',
              ),
              SizedBox(height: 16),
              if (widget.communicationHelper.luzesParametrizacaoAtiva) ...[
                Text(
                  'Agendamento Programado:',
                  style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 10,
                  children: [
                    for (String dia in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'])
                      ChoiceChip(
                        label: Text(dia),
                        selected: widget.communicationHelper.diasSelecionadosLuzes.contains(dia),
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
                        Text('Hora de ligar'),
                        ElevatedButton(
                          onPressed: () => _selecionarHoraLigar(context),
                          child: Text(widget.communicationHelper.luzesHoraLigar != null ? widget.communicationHelper.luzesHoraLigar!.format(context) : 'Selecionar Hora'),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Hora de desligar'),
                        ElevatedButton(
                          onPressed: () => _selecionarHoraDesligar(context),
                          child: Text(widget.communicationHelper.luzesHoraDesligar != null ? widget.communicationHelper.luzesHoraDesligar!.format(context) : 'Selecionar Hora'),
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
                    backgroundColor: Color.fromARGB(255, 61, 231, 115),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _cancelarParametrizacao,
                  child: Text('Cancelar Agendamento', style: TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 198, 68, 59),
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
                  child: Text('Adicionar Parametrização'),
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
                      for (String dia in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'])
                        ChoiceChip(
                          label: Text(dia),
                          selected: widget.communicationHelper.diasSelecionadosLuzes.contains(dia),
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
                          Text('Hora de ligar'),
                          ElevatedButton(
                            onPressed: () => _selecionarHoraLigar(context),
                            child: Text(widget.communicationHelper.luzesHoraLigar != null ? widget.communicationHelper.luzesHoraLigar!.format(context) : 'Selecionar Hora'),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Hora de desligar'),
                          ElevatedButton(
                            onPressed: () => _selecionarHoraDesligar(context),
                            child: Text(widget.communicationHelper.luzesHoraDesligar != null ? widget.communicationHelper.luzesHoraDesligar!.format(context) : 'Selecionar Hora'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _atualizarParametrizacao,
                    child: Text('Gravar Agendamento'),
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
