import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_failure.dart';
import 'firebase_environment.dart';
import 'live_refresh.dart';
import 'network_failure.dart';
import 'emulator_probe_stub.dart'
    if (dart.library.io) 'emulator_probe_io.dart'
    if (dart.library.js_interop) 'emulator_probe_web.dart';

class SessionChangedException extends FormatException {
  const SessionChangedException(super.message);
}

class SessionAccessException extends FormatException {
  const SessionAccessException(super.message);
}

/// SDK transport only. Company selection, roles and domain sessions stay in
/// each app's repository; this gateway cannot authorize a business operation.
/// The emulators are used unless the build is for staging (see
/// [buildFirebaseEnvironment]); the class keeps its name from that time.
class LocalFirebaseGateway implements NetworkProblemSource {
  LocalFirebaseGateway._(
    this._auth,
    this._functions,
    this._host, [
    this._firestore,
  ]);

  /// [host] is the emulator host of a local build and null in staging.
  factory LocalFirebaseGateway.attach(
    FirebaseAuth auth,
    FirebaseFunctions functions,
    String? host,
  ) {
    requireFirebaseTarget(
      buildFirebaseEnvironment,
      projectId: auth.app.options.projectId,
      host: host,
    );
    return LocalFirebaseGateway._(auth, functions, host);
  }

  /// Emulator host; null when connected to a real project.
  final String? _host;

  /// Server of the calls when the build names one ([buildApiServer]); null
  /// sends them to the Cloud Functions of the project or to the emulator.
  final Uri? _server = buildApiServer;

  /// Where a local build checks the server: the local server of the calls,
  /// when the build names one, or the functions emulator.
  Future<NetworkProblem?> _probe(String host) {
    final server = _server;
    return server == null
        ? probeConnection(host)
        : probeConnection(server.host, port: server.port);
  }
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  /// Configured by [connect]; with [attach] the caller already configured the
  /// app's Firestore for the emulator.
  final FirebaseFirestore? _firestore;
  int _generation = 0;
  NetworkProblem? _lastNetworkProblem;

  /// Reason of the latest call without answer; kept for the read-only banner.
  @override
  NetworkProblem? get lastNetworkProblem => _lastNetworkProblem;

  /// The device confirms why no answer came; the reason is kept.
  Future<NetworkException> _noAnswer(NetworkProblem fallback) async {
    // A real project has no emulator to check: the assumed reason stays.
    final host = _host;
    final failure = await confirmNetworkProblem(
      fallback,
      () async => host == null ? null : _probe(host),
    );
    _lastNetworkProblem = failure.problem;
    return failure;
  }

  /// Change signals of the live refresh. Only counters are read directly
  /// from Firestore; data keeps coming from the server queries.
  LiveSignalSource get liveSignals => FirestoreLiveSignals(
    _firestore ?? FirebaseFirestore.instanceFor(app: _auth.app),
    () => uid,
  );
  String? get uid => _auth.currentUser?.uid;
  String? get email => _auth.currentUser?.email;
  bool get emailVerified => _auth.currentUser?.emailVerified ?? false;
  /// [stagingOptions] are the options `flutterfire configure` generated for
  /// the app; read only by a staging build.
  static Future<LocalFirebaseGateway> connect({
    FirebaseOptions Function()? stagingOptions,
  }) async {
    if (buildFirebaseEnvironment == FirebaseEnvironment.staging) {
      final app = await initializeStagingApp(stagingOptions);
      final auth = FirebaseAuth.instanceFor(app: app);
      // E-mails of Auth (recovery and confirmation) in Portuguese.
      await auth.setLanguageCode('pt-BR');
      if (kIsWeb) await auth.setPersistence(Persistence.SESSION);
      final functions = FirebaseFunctions.instanceFor(
        app: app,
        region: 'southamerica-east1',
      );
      final firestore = FirebaseFirestore.instanceFor(app: app);
      firestore.settings = const Settings(persistenceEnabled: false);
      return LocalFirebaseGateway._(auth, functions, null, firestore);
    }
    const supplied = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
    final host = supplied.isEmpty
        ? (kIsWeb ? '127.0.0.1' : '10.0.2.2')
        : supplied;
    if (!['127.0.0.1', 'localhost', '10.0.2.2'].contains(host))
      throw const FormatException('Esta versão usa somente Firebase local.');
    final app = await Firebase.initializeApp(
      name: '[DEFAULT]',
      demoProjectId: 'demo-caopanheiro-local',
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
    if (kIsWeb) await auth.setPersistence(Persistence.SESSION);
    final functions = FirebaseFunctions.instanceFor(
      app: app,
      region: 'southamerica-east1',
    );
    functions.useFunctionsEmulator(host, 5001, automaticHostMapping: false);
    final firestore = FirebaseFirestore.instanceFor(app: app);
    firestore.settings = const Settings(persistenceEnabled: false);
    firestore.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
    return LocalFirebaseGateway._(auth, functions, host, firestore);
  }

  Future<T> _translate<T>(
    Future<T> Function() operation, {
    bool signingIn = false,
  }) async {
    try {
      return await operation();
    } on NetworkException catch (error) {
      _lastNetworkProblem = error.problem;
      rethrow;
    } on TimeoutException {
      throw await _noAnswer(NetworkProblem.timeout);
    } on FirebaseAuthException catch (error) {
      final fallback = networkFallbackFor(error.code);
      if (fallback != null) throw await _noAnswer(fallback);
      throw authFailure(error.code, signingIn: signingIn);
    } on FirebaseFunctionsException catch (error) {
      if (isAppOutdated(error.code, error.details)) {
        throw const AppOutdatedException();
      }
      if (error.code == 'failed-precondition' &&
          error.details is Map &&
          error.details['reason'] == 'SERVICE_QUOTE_CHANGED') {
        throw ServiceQuoteChangedException(
          Map<String, dynamic>.from(error.details as Map),
        );
      }
      final fallback = networkFallbackFor(error.code);
      if (fallback != null) throw await _noAnswer(fallback);
      if (['unauthenticated', 'permission-denied'].contains(error.code))
        throw SessionAccessException(error.message ?? 'Acesso indisponível.');
      throw FormatException(
        error.message ?? 'Não foi possível concluir a operação.',
      );
    }
  }

  Future<void> signIn(String email, String password) => _translate(() async {
    final generation = ++_generation;
    await _auth.signOut();
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (generation != _generation) {
      await _auth.signOut();
      throw const SessionChangedException('Sessão encerrada.');
    }
  }, signingIn: true);
  Future<void> signUp(String email, String password, String name) =>
      _translate(() async {
        final generation = ++_generation;
        final result = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        if (generation != _generation) {
          await _auth.signOut();
          throw const SessionChangedException('Sessão encerrada.');
        }
        await result.user!.updateDisplayName(name.trim());
      }, signingIn: true);
  Future<void> reloadIdentity() => _translate(() async {
    await _auth.currentUser?.reload();
  });
  Future<void> sendVerification() => _translate(() async {
    final user = _auth.currentUser;
    if (user == null) throw const SessionAccessException('Entre na sua conta.');
    await user.sendEmailVerification();
  });

  /// Native reset link. Unknown e-mails end silently so the caller can answer
  /// generically without revealing whether an account exists.
  Future<void> sendPasswordReset(String email) => _translate(() async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      if (error.code != 'user-not-found') rethrow;
    }
  }, signingIn: true);

  /// Providers of the signed-in identity, e.g. `password` and `google.com`.
  List<String> get providers =>
      _auth.currentUser?.providerData.map((p) => p.providerId).toList() ??
      const [];

  /// Google popup on the web PWA and the provider page on Android. Firebase
  /// keeps one account per e-mail, so an e-mail already registered with a
  /// password is refused instead of creating a second identity; the person
  /// signs in with the password and links Google. Signing in proves only the
  /// identity: links, roles and administrative access stay with the backend.
  Future<void> signInWithGoogle() => _translate(() async {
    final generation = ++_generation;
    await _auth.signOut();
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(provider);
      } else {
        await _auth.signInWithProvider(provider);
      }
    } on FirebaseAuthException catch (error) {
      if (error.code == 'network-request-failed') rethrow;
      throw await googleFailure(error.code, _checkConnection);
    }
    if (generation != _generation) {
      await _auth.signOut();
      throw const SessionChangedException('Sessão encerrada.');
    }
  });

  /// Adds Google to the signed-in account, keeping the same UID and links.
  Future<void> linkGoogle() => _translate(() async {
    final user = _auth.currentUser;
    if (user == null) throw const SessionAccessException('Entre na sua conta.');
    try {
      if (kIsWeb) {
        await user.linkWithPopup(GoogleAuthProvider());
      } else {
        await user.linkWithProvider(GoogleAuthProvider());
      }
    } on FirebaseAuthException catch (error) {
      if (error.code == 'network-request-failed') rethrow;
      throw await googleFailure(error.code, _checkConnection);
    }
  });

  /// Whether this device reaches the server of the build: the emulator of a
  /// local build or, in staging, the server of the calls. The web is left
  /// out: its Google popup already reports network-request-failed offline.
  Future<NetworkProblem?> _checkConnection() async {
    if (kIsWeb) return null;
    final host = _host;
    if (host != null) return _probe(host);
    final server = _server;
    return server == null
        ? null
        : probeConnection(server.host, port: server.port);
  }
  Future<void> acceptAdministrativeToken(String token) => _translate(() async {
    final owner = uid;
    final generation = _generation;
    final result = await _auth.signInWithCustomToken(token);
    if (generation != _generation || result.user?.uid != owner) {
      await _auth.signOut();
      throw const SessionChangedException('Sessão encerrada.');
    }
  });

  Future<void> signOut() async {
    ++_generation;
    await _auth.signOut();
  }

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> input,
  ) => _translate(() async {
    final generation = _generation;
    final owner = uid;
    if (owner == null)
      throw const SessionAccessException('Entre na sua conta.');
    // Only a local build has an emulator host to check before going out.
    final host = _host;
    if (probeBeforeCalls && host != null) {
      final problem = await _probe(host);
      if (problem != null) throw NetworkException.of(problem);
    }
    try {
      // Resolve Auth failures before Functions wraps token errors as "unknown".
      await _auth.currentUser?.getIdToken();
      if (generation != _generation || owner != uid) {
        throw const SessionChangedException('Sessão encerrada.');
      }
      final response = await callableOf(
        _functions,
        name,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
        server: _server,
      ).call<Map<String, dynamic>>(withClientProtocol(input));
      if (generation != _generation || owner != uid)
        throw const SessionChangedException('Sessão encerrada.');
      return Map<String, dynamic>.from(response.data);
    } catch (_) {
      if (generation != _generation || owner != uid)
        throw const SessionChangedException('Sessão encerrada.');
      rethrow;
    }
  });
}

/// Explicit retries only; no timer, persistent request, queue or background send.
class ExplicitCommands {
  bool get hasPending => _pending != null;
  Map<String, dynamic>? _pending;
  String? _fingerprint;
  void clear() {
    _pending = null;
    _fingerprint = null;
  }

  Future<Map<String, dynamic>> run(
    String name,
    Map<String, dynamic> data,
    Future<Map<String, dynamic>> Function(String, Map<String, dynamic>) send,
  ) async {
    final fingerprint = jsonEncode([name, data]);
    if (_pending != null && fingerprint != _fingerprint)
      throw const FormatException(
        'Existe uma operação sem confirmação. Repita os mesmos dados ou atualize antes de outra alteração.',
      );
    _fingerprint = fingerprint;
    _pending ??= {
      ...data,
      'requestId': List.generate(
        32,
        (_) => Random.secure().nextInt(16).toRadixString(16),
      ).join(),
    };
    final attempt = _pending!;
    try {
      final response = await send(name, attempt);
      if (identical(_pending, attempt)) clear();
      return response;
    } on NetworkException {
      rethrow;
    } catch (_) {
      if (identical(_pending, attempt)) clear();
      rethrow;
    }
  }
}
