import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Reusable presentation for an existing empty/restricted/error message.
/// All original text and display conditions are supplied by the consuming app.
class AppMessageState extends StatelessWidget {
  const AppMessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.padding = const EdgeInsets.symmetric(vertical: 40),
    this.iconSize = 52,
    this.titleGap = 16,
    this.messageGap = 8,
    this.mainAxisSize = MainAxisSize.max,
    this.titleTextAlign = TextAlign.center,
    this.center = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final EdgeInsets padding;
  final double iconSize;
  final double titleGap;
  final double messageGap;
  final MainAxisSize mainAxisSize;
  final TextAlign? titleTextAlign;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: mainAxisSize,
        children: [
          Icon(icon, size: iconSize, color: AppColors.primary),
          SizedBox(height: titleGap),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: titleTextAlign,
          ),
          SizedBox(height: messageGap),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
    return center ? Center(child: content) : content;
  }
}

/// Existing inline spinner; does not change button state or label.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator.button({super.key, this.dimension = 21});

  final double dimension;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: dimension,
    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );
}

/// Presentation only. Retry behavior and messages stay in the app.
class AppNoticeBanner extends StatelessWidget {
  const AppNoticeBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.background,
    required this.iconColor,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color background;
  final Color iconColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    child: ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(message),
      trailing: action,
    ),
  );
}
