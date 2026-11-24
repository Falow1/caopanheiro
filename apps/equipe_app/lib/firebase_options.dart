// Options of the Firebase app of this application in the staging project
// caopanheiro-staging-fly, from `firebase apps:sdkconfig`. Only a build with
// --dart-define=CAOPANHEIRO_ENV=staging reads them; the local build keeps
// using the emulators. These identify the app to Firebase and are not secret.
import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const FormatException(
        'Configuração do Firebase de staging disponível só no Android.',
      );
    }
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCwZSi2QHXUZ4_IDq0LnOakxDaAPZ-UPhY',
    appId: '1:597374224074:android:7a1463075c7506f8ed9633',
    messagingSenderId: '597374224074',
    projectId: 'caopanheiro-staging-fly',
    storageBucket: 'caopanheiro-staging-fly.firebasestorage.app',
  );
}
