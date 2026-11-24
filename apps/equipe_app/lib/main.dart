import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'state/workforce_controller.dart';
import 'modules/professional/data/firebase_professional_repository.dart'
    as pro_data;
import 'modules/professional/state/app_controller.dart' as pro;
import 'modules/driver/data/firebase_transport_repository.dart' as driver_data;
import 'modules/driver/state/app_controller.dart' as delivery;
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/firebase_local_repository.dart';
import 'data/offline_catalog_repository.dart';
import 'data/sql_catalog_store.dart';
import 'firebase_options.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final remote = await FirebaseLocalRepository.connect(
      stagingOptions: () => DefaultFirebaseOptions.currentPlatform,
    );
    final repository = OfflineCatalogRepository(
      remote,
      await SqlCatalogStore.open(),
    );
    late WorkforceController workforce;
    final professional = pro.AppController(
      pro_data.FirebaseProfessionalRepository(
        remote.gateway,
        await SqlSnapshotCache.open('unified_professional_v1.db'),
      ),
      onSignOut: () => workforce.signOut(),
    );
    final driver = delivery.AppController(
      driver_data.FirebaseTransportRepository(
        remote.gateway,
        await SqlSnapshotCache.open('unified_driver_v1.db'),
      ),
      onSignOut: () => workforce.signOut(),
    );
    final controller = AppController(
      repository,
      catalogOnly: true,
      unified: true,
      onSignOut: () => workforce.signOut(),
      beforeSignIn: () => workforce.closingSession,
    );
    workforce = WorkforceController(controller, professional, driver);
    await controller.restoreSession();
    runApp(InternalApp(controller: controller, workforce: workforce));
  } catch (_) {
    final local = buildFirebaseEnvironment == FirebaseEnvironment.local;
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                local
                    ? 'Não foi possível iniciar o Firebase local. Confira os emuladores e abra o aplicativo novamente.'
                    : 'Não foi possível conectar ao servidor. Confira a internet e abra o aplicativo novamente.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
