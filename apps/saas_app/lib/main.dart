import 'package:flutter/material.dart';
import 'package:caopanheiro_core/caopanheiro_core.dart';

import 'app.dart';
import 'data/firebase_saas_repository.dart';
import 'firebase_options.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(
    FirebaseSaasRepository(
      await LocalFirebaseGateway.connect(
        stagingOptions: () => DefaultFirebaseOptions.currentPlatform,
      ),
      await SqlSnapshotCache.open('saas_v1.db'),
    ),
  );
  await controller.restoreSession();
  runApp(SaasAdminApp(controller: controller));
}
