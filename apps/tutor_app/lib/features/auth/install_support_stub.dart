import 'install_support.dart';

InstallSupport createInstallSupport() => const _NoInstall();

class _NoInstall extends InstallSupport {
  const _NoInstall();

  @override
  InstallDevice get device => InstallDevice.other;
  @override
  bool get installed => false;
  @override
  bool get closed => false;
  @override
  void close() {}
  @override
  Future<InstallResult> prompt() async => InstallResult.unavailable;
}
