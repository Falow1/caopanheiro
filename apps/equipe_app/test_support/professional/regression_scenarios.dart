import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'app.dart';
import 'in_memory_professional_repository.dart';
import 'package:equipe_app/modules/professional/domain/models.dart';
import 'package:equipe_app/modules/professional/state/app_controller.dart';
import 'package:caopanheiro_test_support/ui_regression.dart';

void defineRegressionScenarios({
  bool host = false,
  Future<void> Function(WidgetTester)? capture,
}) {
  late AppController controller;
  setUp(() {
    controller = AppController(InMemoryProfessionalRepository());
  });
  tearDown(() {
    controller.dispose();
  });
  Future<void> launch(WidgetTester tester) async {
    prepareView(tester, host: host);
    await tester.pumpWidget(ProfessionalApp(controller: controller));
    await settle(tester);
  }

  testWidgets('profissional: abas, logout, bloqueio de retorno e novo login', (
    tester,
  ) async {
    await launch(tester);
    await navigationAndLogout(
      tester,
      signedIn: () => controller.professional != null,
      stateCleared: () =>
          controller.professional == null &&
          controller.appointments.isEmpty &&
          controller.failure == null,
    );
    if (capture != null) await capture(tester);
  });
  testWidgets(
    'profissional: iniciar, adicionar observação e concluir atendimento',
    (tester) async {
      await launch(tester);
      await login(tester);
      await selectTab(tester, 1);
      await tapText(tester, 'Thor');
      await tapText(tester, 'Iniciar atendimento');
      await waitFor(
        tester,
        () =>
            !controller.busy &&
            controller.appointments
                    .singleWhere((item) => item.id == 'a-1')
                    .status ==
                AppointmentStatus.inProgress,
        'início do atendimento',
      );
      expect(
        controller.appointments.singleWhere((item) => item.id == 'a-1').status,
        AppointmentStatus.inProgress,
      );
      await tapText(tester, 'Adicionar observação');
      await tapText(tester, 'Salvar');
      expect(find.text('Escreva uma observação para salvar.'), findsOneWidget);
      await fillField(tester, 'Observação', 'Observação QA');
      await tapText(tester, 'Salvar');
      await waitFor(
        tester,
        () =>
            !controller.busy &&
            controller.appointments
                .singleWhere((item) => item.id == 'a-1')
                .observations
                .isNotEmpty,
        'observação salva',
      );
      expect(
        controller.appointments
            .singleWhere((item) => item.id == 'a-1')
            .observations
            .single
            .text,
        'Observação QA',
      );
      await tapText(tester, 'Finalizar atendimento');
      await tapTarget(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Finalizar atendimento'),
        ),
      );
      await waitFor(
        tester,
        () =>
            !controller.busy &&
            controller.appointments
                    .singleWhere((item) => item.id == 'a-1')
                    .status ==
                AppointmentStatus.completed,
        'conclusão do atendimento',
      );
      expect(
        controller.appointments.singleWhere((item) => item.id == 'a-1').status,
        AppointmentStatus.completed,
      );
      expect(find.text('Iniciar atendimento'), findsNothing);
      expect(find.text('Adicionar observação'), findsNothing);
      expect(controller.busy, isFalse);
      expect(controller.error, isNull);
      if (capture != null) await capture(tester);
    },
  );
}
