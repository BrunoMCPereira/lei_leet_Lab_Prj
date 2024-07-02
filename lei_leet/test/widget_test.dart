import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lei_leet/main.dart';
import 'package:lei_leet/comunicacao.dart';
import 'package:lei_leet/mudancaEstado.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    final String brokerAddress = '192.168.1.239';
    final DeviceState deviceState = DeviceState();
    final CommunicationHelper communicationHelper = CommunicationHelper(brokerAddress, deviceState);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => deviceState,
        child: MyApp(
          brokerAddress: brokerAddress,
          communicationHelper: communicationHelper,
        ),
      ),
    );

    // Verifique se o contador começa em 0
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Toque no ícone '+' e verifique se o contador incrementa
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verifique se o contador incrementou
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
