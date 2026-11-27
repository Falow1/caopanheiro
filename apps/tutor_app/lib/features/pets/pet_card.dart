import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppPetIcon, AppRadii;
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/pet.dart';

/// Card of one pet, the same in the list of the account and in the choice of
/// the booking: icon of the breed at the left, name and species · breed in
/// the middle, the [trailing] mark at the right, both at a fixed size, and
/// the [notes] and the [footer] below. Long names and breeds wrap; nothing
/// is cut. In a [PetCardGrid] the cards of a row share the height, with the
/// footer at the bottom ([fill]).
class PetCard extends StatelessWidget {
  const PetCard({
    super.key,
    required this.pet,
    this.onTap,
    this.selected = false,
    this.dimmed = false,
    this.trailing,
    this.notes = const [],
    this.footer,
    this.fill = false,
  });

  final Pet pet;
  final VoidCallback? onTap;

  /// Marked in a choice: mint background and green border.
  final bool selected;

  /// The pet cannot be chosen: the icon fades.
  final bool dimmed;
  final Widget? trailing;

  /// Lines under species · breed, as the notice of a pet not served.
  final List<Widget> notes;
  final Widget? footer;

  /// In a row of a [PetCardGrid] with several columns: the card takes the
  /// height of the row and keeps the footer at the bottom.
  final bool fill;

  /// Size of the icon of the breed in every card.
  static const iconSize = 56.0;

  /// Space kept for the mark at the right, so text widths line up.
  static const trailingSize = 28.0;

  @override
  Widget build(BuildContext context) {
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Opacity(
          opacity: dimmed ? 0.45 : 1,
          child: AppPetIcon(
            icon: pet.breedIcon,
            size: iconSize,
            semanticLabel: pet.breed,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(pet.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text('${pet.species} · ${pet.breed}'),
              ...notes,
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox.square(
          dimension: trailingSize,
          child: Center(child: trailing),
        ),
      ],
    );
    return Material(
      color: selected ? AppColors.mint : AppColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.r20,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.r20,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
            children: [header, if (fill) const Spacer(), ?footer],
          ),
        ),
      ),
    );
  }
}

/// The round check of a pet chosen in the booking.
class PetCheck extends StatelessWidget {
  const PetCheck({super.key, required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      color: selected ? AppColors.primary : Colors.transparent,
      shape: BoxShape.circle,
      border: Border.all(color: selected ? AppColors.primary : AppColors.muted),
    ),
    child: selected
        ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
        : null,
  );
}

/// Pet cards in [columns], [gap] apart, the cards of each row with the height
/// of the tallest. One column is a plain list.
class PetCardGrid extends StatelessWidget {
  const PetCardGrid({
    super.key,
    required this.columns,
    required this.children,
    this.gap = 12,
  });
  final int columns;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i += columns)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
          child: columns == 1
              ? children[i]
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = i; j < i + columns; j++) ...[
                        if (j > i) SizedBox(width: gap),
                        Expanded(
                          child: j < children.length
                              ? children[j]
                              : const SizedBox(),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
    ],
  );
}
