// Options of the Firebase app of this application in the staging project
// caopanheiro-staging-fly, from `firebase apps:sdkconfig`. Only a build with
// --dart-define=CAOPANHEIRO_ENV=staging reads them; the local build keeps
// using the emulators. These identify the app to Firebase and are not secret.
import 'package:caopanheiro_core/caopanheiro_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb) {
      throw const FormatException(
        'Configuração do Firebase de staging disponível só na Web.',
      );
    }
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB7hhGTPvO2rZE4BNshANFefjQ5F3Jt9gY',
    appId: '1:597374224074:web:151f4b849b146fe6ed9633',
    messagingSenderId: '597374224074',
    projectId: 'caopanheiro-staging-fly',
    authDomain: 'caopanheiro-staging-fly.firebaseapp.com',
    storageBucket: 'caopanheiro-staging-fly.firebasestorage.app',
  );
}
