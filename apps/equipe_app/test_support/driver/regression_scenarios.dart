import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'app.dart';
import 'in_memory_transport_repository.dart';
import 'package:equipe_app/modules/driver/domain/models.dart';
import 'package:equipe_app/modules/driver/state/app_controller.dart';
import 'package:caopanheiro_test_support/ui_regression.dart';

void defineRegressionScenarios({
  bool host = false,
  Future<void> Function(WidgetTester)? capture,
}) {
  late AppController controller;
  setUp(() {
    controller = AppController(InMemoryTransportRepository());
  });
  tearDown(() {
    controller.dispose();
  });
  Future<void> launch(WidgetTester tester) async {
    prepareView(tester, host: host);
    await tester.pumpWidget(DriverApp(controller: controller));
    await settle(tester);
  }

  testWidgets('entregador: empresa, abas, logout e novo login', (tester) async {
    await launch(tester);
    await navigationAndLogout(
      tester,
      driver: true,
      signedIn: () => controller.profile != null,
      stateCleared: () =>
          controller.profile == null &&
          controller.memberships.isEmpty &&
          controller.transports.isEmpty &&
          controller.activeTenantId == null &&
          controller.failure == null,
    );
    if (capture != null) await capture(tester);
  });
  testWidgets(
    'entregador: deslocamento, coleta com checklist, transporte e entrega',
    (tester) async {
      await launch(tester);
      await login(tester, driver: true);
      await selectTab(tester, 1);
      await tapText(tester, 'Thor');
      await tapText(tester, 'Iniciar deslocamento');
      await tapText(tester, 'Iniciar');
      await waitFor(
        tester,
        () =>
            !controller.busy &&
            controller.transportById('TRA-1042').status ==
                TransportStatus.goingToOrigin,
        'deslocamento',
      );
      expect(
        controller.transportById('TRA-1042').status,
        TransportStatus.goingToOrigin,
      );
      await tapText(tester, 'Confirmar coleta');
      for (
        var i = 0;
        i < find.byType(CheckboxListTile).evaluate().length;
        i++
      ) {
        await tapTarget(tester, find.byType(CheckboxListTile).at(i));
      }
      await tapTarget(
        tester,
        find.widgetWithText(FilledButton, 'Salvar conferência'),
      );
      await waitFor(
        tester,
        () =>
            !controller.busy &&
            controller.transportById('TRA-1042').status ==
                TransportStatus.petCollected,
        'coleta',
      );
      expect(
        controller.transportById('TRA-1042').status,
        TransportStatus.petCollected,
      );
      await tapText(tester, 'Iniciar transporte');
      await tapTarget(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Iniciar transporte'),
        ),
      );
      await waitFor(
        tester,
        () =>
            !controller.busy &&
            controller.transportById('TRA-1042').status ==
                TransportStatus.inTransit,
        'transporte',
      );
      expect(
        controller.transportById('TRA-1042').status,
        TransportStatus.inTransit,
      );
      await tapText(tester, 'Confirmar entrega');
      expect(find.byType(CheckboxListTile), findsNothing);
      await tapTarget(
        tester,
        find.widgetWithText(FilledButton, 'Confirmar entrega').last,
      );
      await waitFor(
        tester,
        () =>
            !controller.busy &&
            controller.transportById('TRA-1042').status ==
                TransportStatus.delivered,
        'entrega',
      );
      expect(
        controller.transportById('TRA-1042').status,
        TransportStatus.delivered,
      );
      await tapText(tester, 'Próximo transporte');
      expect(find.text('Transporte concluído'), findsWidgets);
      expect(controller.transportById('TRA-1042').events.length, 5);
      expect(controller.busy, isFalse);
      expect(controller.error, isNull);
      if (capture != null) await capture(tester);
    },
  );
}
