import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../comunicacao.dart';
import '../mudancaEstado.dart';
import 'dart:developer' as developer;

class TemperatureScreen extends StatefulWidget {
  final CommunicationHelper communicationHelper;

  TemperatureScreen({required this.communicationHelper});

  @override
  _TemperatureScreenState createState() => _TemperatureScreenState();
}

class _TemperatureScreenState extends State<TemperatureScreen> {
  String? temperaturaAtual;
  String? temperaturaPretendida;
  String? temperaturaPretendidaParametrizacao;
  bool isEditingParametrizacao = false;
  bool isDefinindoTemperatura = false;
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
      widget.communicationHelper.solicitarParametrizacao('ar_condicionado');
      _carregarDados();
    });
  }

  void _carregarDados() {
    setState(() {
      temperaturaAtual = widget.communicationHelper.deviceState.temperaturaAtual?.toString() ?? '24.0';
      temperaturaPretendida = widget.communicationHelper.deviceState.estadoArCondicionado == "ligado"
          ? widget.communicationHelper.deviceState.temperaturaAtual?.toString() ?? '24.0'
          : 'inativo';
      temperaturaPretendidaParametrizacao = widget.communicationHelper.arCondicionadotemperaturaPretendidaParametrizacao?.toString() ?? '24.0';
      isEditingParametrizacao = widget.communicationHelper.arCondicionadoParametrizacaoAtiva;
    });
    developer.log('Dados iniciais carregados', name: 'TemperatureScreen');
    developer.log('temperaturaAtual: $temperaturaAtual', name: 'TemperatureScreen');
    developer.log('temperaturaPretendida: $temperaturaPretendida', name: 'TemperatureScreen');
    developer.log('temperaturaPretendidaParametrizacao: $temperaturaPretendidaParametrizacao', name: 'TemperatureScreen');
    developer.log('isEditingParametrizacao: $isEditingParametrizacao', name: 'TemperatureScreen');
  }

  void _alterarTemperatura(double novaTemperatura) {
    setState(() {
      temperaturaPretendida = novaTemperatura.toStringAsFixed(1);
    });
    developer.log('temperaturaPretendida alterada para: $temperaturaPretendida', name: 'TemperatureScreen');
  }

  void _alterarTemperaturaParametrizacao(double novaTemperatura) {
    setState(() {
      temperaturaPretendidaParametrizacao = novaTemperatura.toStringAsFixed(1);
    });
    developer.log('temperaturaPretendidaParametrizacao alterada para: $temperaturaPretendidaParametrizacao', name: 'TemperatureScreen');
  }

 void _definirTemperatura() {
    setState(() {
      if (double.parse(temperaturaPretendida!) < double.parse(temperaturaAtual!)) {
        widget.communicationHelper.ligarArCondicionado();
        widget.communicationHelper.desligarLuz();
        developer.log('Ar condicionado ligado e luz desligada', name: 'TemperatureScreen');
      } else {
        widget.communicationHelper.ligarLuz();
        widget.communicationHelper.desligarArCondicionado();
        developer.log('Luz ligada e ar condicionado desligado', name: 'TemperatureScreen');
      }

      widget.communicationHelper.arCondicionadoParametrizacaoAtiva = true;
      isDefinindoTemperatura = false;
    });

    final valoresAtuais = {
      "estado": double.parse(temperaturaPretendida!) < double.parse(temperaturaAtual!) ? "ligar" : "desligar",
      "temperatura_pretendida": temperaturaPretendida
    };
    widget.communicationHelper.definirValoresAtuais("ar_condicionado", valoresAtuais);

    developer.log('Valores atuais definidos: $valoresAtuais', name: 'TemperatureScreen');
  }


  void _desligar() {
    widget.communicationHelper.desligarArCondicionado();
    widget.communicationHelper.desligarLuz();
    setState(() {
      widget.communicationHelper.arCondicionadoParametrizacaoAtiva = false;
      isDefinindoTemperatura = false;
    });
  }

  Future<void> _selecionarHoraLigar(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: widget.communicationHelper.arCondicionadoHoraLigar ?? TimeOfDay.now(),
    );
    if (picked != null && picked != widget.communicationHelper.arCondicionadoHoraLigar) {
      setState(() {
        widget.communicationHelper.arCondicionadoHoraLigar = picked;
      });
      developer.log('Hora de ligar selecionada: ${widget.communicationHelper.arCondicionadoHoraLigar}', name: 'TemperatureScreen');
    }
  }

  Future<void> _selecionarHoraDesligar(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: widget.communicationHelper.arCondicionadoHoraDesligar ?? TimeOfDay.now(),
    );
    if (picked != null && picked != widget.communicationHelper.arCondicionadoHoraDesligar) {
      setState(() {
        widget.communicationHelper.arCondicionadoHoraDesligar = picked;
      });
      developer.log('Hora de desligar selecionada: ${widget.communicationHelper.arCondicionadoHoraDesligar}', name: 'TemperatureScreen');
    }
  }

  void _toggleDiaSelecionado(String dia) {
    setState(() {
      if (widget.communicationHelper.diasSelecionadosArCondicionado.contains(dia)) {
        widget.communicationHelper.diasSelecionadosArCondicionado.remove(dia);
      } else {
        widget.communicationHelper.diasSelecionadosArCondicionado.add(dia);
      }
    });
    developer.log('Dias selecionados: ${widget.communicationHelper.diasSelecionadosArCondicionado}', name: 'TemperatureScreen');
  }

  Future<void> _atualizarParametrizacao() async {
    if (widget.communicationHelper.diasSelecionadosArCondicionado.isEmpty ||
        widget.communicationHelper.arCondicionadoHoraLigar == null ||
        widget.communicationHelper.arCondicionadoHoraDesligar == null ||
        temperaturaPretendidaParametrizacao == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Erro"),
            content: Text("Por favor, preencha todos os campos antes de gravar a parametrização."),
            actions: [
              ElevatedButton(
                child: Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    final parametros = {
      "estado": "ativo",
      "modelo": "habilitar",
      "dias_semana": widget.communicationHelper.diasSelecionadosArCondicionado,
      "horario": {
        "ligar": widget.communicationHelper.arCondicionadoHoraLigar != null
            ? '${widget.communicationHelper.arCondicionadoHoraLigar!.hour.toString().padLeft(2, '0')}:${widget.communicationHelper.arCondicionadoHoraLigar!.minute.toString().padLeft(2, '0')}'
            : null,
        "desligar": widget.communicationHelper.arCondicionadoHoraDesligar != null
            ? '${widget.communicationHelper.arCondicionadoHoraDesligar!.hour.toString().padLeft(2, '0')}:${widget.communicationHelper.arCondicionadoHoraDesligar!.minute.toString().padLeft(2, '0')}'
            : null,
      },
      "temperatura": temperaturaPretendidaParametrizacao,
    };
    widget.communicationHelper.programarParametros("ar_condicionado", parametros);
    await widget.communicationHelper.solicitarParametrizacao('ar_condicionado'); // Solicitar novamente para garantir que os dados sejam atualizados
    _carregarDados(); // Atualiza os dados após a mudança de parametrização
    setState(() {
      isEditingParametrizacao = false;
    }); // Garantir que a UI seja atualizada

    developer.log('Parametrização atualizada: $parametros', name: 'TemperatureScreen');
  }

  Future<void> _cancelarParametrizacao() async {
    setState(() {
      widget.communicationHelper.arCondicionadoParametrizacaoAtiva = false;
      widget.communicationHelper.diasSelecionadosArCondicionado.clear();
      widget.communicationHelper.arCondicionadoHoraLigar = null;
      widget.communicationHelper.arCondicionadoHoraDesligar = null;
      temperaturaPretendidaParametrizacao = null;
    });
    final parametros = {
      "estado": "inativo",
      "modelo": "desabilitar",
      "dias_semana": [],
      "horario": {
        "ligar": "inativo",
        "desligar": "inativo",
      },
      "temperatura": "inativo",
    };
    widget.communicationHelper.programarParametros("ar_condicionado", parametros);
    _carregarDados(); // Atualiza os dados após o cancelamento de parametrização

    developer.log('Parametrização cancelada: $parametros', name: 'TemperatureScreen');
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
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 16),
              Text(
                'Controle da Temperatura',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              SizedBox(height: 16),
              if (isEditingParametrizacao) ...[
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
                        selected: widget.communicationHelper.diasSelecionadosArCondicionado.contains(dia),
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
                          child: Text(widget.communicationHelper.arCondicionadoHoraLigar != null ? widget.communicationHelper.arCondicionadoHoraLigar!.format(context) : 'Selecionar Hora'),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Hora de desligar'),
                        ElevatedButton(
                          onPressed: () => _selecionarHoraDesligar(context),
                          child: Text(widget.communicationHelper.arCondicionadoHoraDesligar != null ? widget.communicationHelper.arCondicionadoHoraDesligar!.format(context) : 'Selecionar Hora'),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Temperatura Pretendida:',
                  style: TextStyle(fontSize: 18),
                ),
                Slider(
                  value: double.tryParse(temperaturaPretendidaParametrizacao ?? temperaturaAtual!) ?? 24.0,
                  min: 16,
                  max: 30,
                  divisions: 28,
                  label: temperaturaPretendidaParametrizacao,
                  onChanged: (double value) {
                    _alterarTemperaturaParametrizacao(value);
                  },
                ),
                ElevatedButton(
                  onPressed: _atualizarParametrizacao,
                  child: Text('Gravar Agendamento',style: TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _cancelarParametrizacao,
                  child: Text('Cancelar Agendamento',style: TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ] else ...[
                if (widget.communicationHelper.arCondicionadoParametrizacaoAtiva || isDefinindoTemperatura) ...[
                  Text(
                    'Temperatura Atual:',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    '${deviceState.temperaturaAtual.toStringAsFixed(1)} °C',
                    style: TextStyle(fontSize: 18, color: Colors.blue),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Temperatura Pretendida:',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    '${temperaturaPretendida ?? temperaturaAtual} °C',
                    style: TextStyle(fontSize: 18, color: Colors.blue),
                  ),
                  Slider(
                    value: (temperaturaPretendida != null ? double.tryParse(temperaturaPretendida!) : double.tryParse(temperaturaAtual!)) ?? 24.0,
                    min: 16,
                    max: 30,
                    divisions: 28,
                    label: temperaturaPretendida,
                    onChanged: (double value) {
                      _alterarTemperatura(value);
                    },
                  ),

                ],
                SizedBox(height: 16),
                ControlSection(
                  title: 'Ar Condicionado',
                  statusText: 'Status: ${widget.communicationHelper.arCondicionadoParametrizacaoAtiva ? 'Ligado' : isDefinindoTemperatura ? 'Definindo' : 'Desligado'}',
                  onControl: () {
                    if (widget.communicationHelper.arCondicionadoParametrizacaoAtiva) {
                      _desligar();
                    } else if (isDefinindoTemperatura) {
                      _definirTemperatura();
                    } else {
                      setState(() {
                        isDefinindoTemperatura = true;
                      });
                      developer.log('Definindo temperatura...', name: 'TemperatureScreen');
                    }
                  },
                  buttonColor: widget.communicationHelper.arCondicionadoParametrizacaoAtiva
                      ? Colors.red
                      : isDefinindoTemperatura
                          ? Colors.amber
                          : Colors.green,
                  buttonText: widget.communicationHelper.arCondicionadoParametrizacaoAtiva
                      ? 'Desligar'
                      : isDefinindoTemperatura
                          ? 'Definir'
                          : 'Ligar',
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isEditingParametrizacao = true;
                      widget.communicationHelper.solicitarParametrizacao('ar_condicionado'); // Adicionei essa linha para carregar os dados ao clicar em "Verificar Agendamento"
                    });
                    developer.log('Editando parametrização...', name: 'TemperatureScreen');
                  },
                  child: Text(
                    widget.communicationHelper.arCondicionadoParametrizacaoAtiva ? 'Verificar Agendamento' : 'Adicionar Agendamento',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
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
