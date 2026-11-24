import 'package:flutter/material.dart';
import 'package:caopanheiro_core/caopanheiro_core.dart';

import 'app.dart';
import 'data/firebase_petshop_repository.dart';
import 'domain/policies/tutor_invite.dart';
import 'firebase_options.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(
    FirebasePetshopRepository(
      await LocalFirebaseGateway.connect(
        stagingOptions: () => DefaultFirebaseOptions.currentPlatform,
      ),
    ),
  )..pendingInvite = tutorInviteCode(Uri.base.toString());
  await controller.restoreSession();
  runApp(TutorApp(controller: controller));
}
