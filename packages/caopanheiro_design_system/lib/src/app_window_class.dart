import 'package:flutter/widgets.dart';

import 'app_dimensions.dart';

/// How a screen is arranged, decided only by the window width: [compact]
/// for phones and narrow windows, [expanded] for desktop and tablets lying
/// down. The device type, the browser and the platform are never checked.
enum AppWindowClass { compact, expanded }

/// The [AppWindowClass] of the window around [context]; rebuilds with it.
AppWindowClass appWindowClassOf(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppDimensions.tutorDesktopBreakpoint
    ? AppWindowClass.expanded
    : AppWindowClass.compact;
