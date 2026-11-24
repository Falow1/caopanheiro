import 'install_support_stub.dart'
    if (dart.library.js_interop) 'install_support_web.dart'
    as platform;

/// The phones that get the install invitation on the login.
enum InstallDevice { android, iphone, other }

/// What came of asking Chrome to install the Tutor.
enum InstallResult { accepted, dismissed, unavailable }

/// What the browser allows for installing the Tutor on the phone.
///
/// Outside the browser (the Android app and tests) there is nothing to
/// install, so the invitation never shows.
abstract class InstallSupport {
  const InstallSupport();

  factory InstallSupport.platform() => platform.createInstallSupport();

  InstallDevice get device;

  /// Already opened from the home screen, or installed from this browser.
  bool get installed;

  /// The tutor closed the invitation on this device.
  bool get closed;
  void close();

  /// Opens Chrome's own install window. [InstallResult.unavailable] means
  /// Chrome has none to offer now, and the steps are shown instead.
  Future<InstallResult> prompt();

  bool get offersInvite =>
      device != InstallDevice.other && !installed && !closed;
}
