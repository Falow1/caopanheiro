import 'package:flutter/material.dart';

import 'app_brand.dart';
import 'app_colors.dart';

/// Icon of a pet's breed in a light mint circle. [icon] is the icon name of
/// the breed list (assets/pet_breeds/{icon}.webp). Without a name, or when the
/// image is missing, the brand paw is shown, so an unknown breed never breaks
/// the card. The visual package receives only the name, never the pet.
class AppPetIcon extends StatelessWidget {
  const AppPetIcon({
    super.key,
    required this.icon,
    this.size = 40,
    this.background = AppColors.mint,
    this.semanticLabel,
  });

  final String? icon;

  /// Diameter of the circle.
  final double size;
  final Color? background;

  /// Read by screen readers, usually the breed name.
  final String? semanticLabel;

  static const package = 'caopanheiro_design_system';
  static String asset(String icon) => 'assets/pet_breeds/$icon.webp';

  @override
  Widget build(BuildContext context) {
    final paw = Semantics(
      label: semanticLabel,
      child: AppPawMark(size: size * 0.48, color: AppColors.primary),
    );
    final name = icon;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: name == null || name.isEmpty
          ? paw
          : Padding(
              padding: EdgeInsets.all(size * 0.06),
              child: Image.asset(
                asset(name),
                package: package,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                semanticLabel: semanticLabel,
                excludeFromSemantics: semanticLabel == null,
                errorBuilder: (_, _, _) => paw,
              ),
            ),
    );
  }
}
