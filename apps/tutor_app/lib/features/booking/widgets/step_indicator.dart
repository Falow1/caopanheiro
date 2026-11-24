import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii, AppTextStyles;

import '../../../core/theme/app_theme.dart';
import '../../navigation/tutor_wide_layout.dart';

/// Names of the steps, under the bars on wide windows.
const bookingStepNames = ['Pets', 'Serviços', 'Horário', 'Revisão'];

/// Names of the steps when the petshop offers transport: it is the fourth.
const bookingStepNamesWithTransport = [
  'Pets',
  'Serviços',
  'Horário',
  'Transporte',
  'Revisão',
];

/// The bars of the booking, four or five; on wide windows, with the names
/// under them.
class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.current, this.total = 4});
  final int current;

  /// Four steps, or five with the transport.
  final int total;

  List<String> get _names =>
      total == 5 ? bookingStepNamesWithTransport : bookingStepNames;

  @override
  Widget build(BuildContext context) {
    if (tutorWide(context)) return _named();
    return Row(
      children: List.generate(
        total,
        (index) => Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index == total - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: index <= current ? AppColors.primary : AppColors.line,
              borderRadius: AppRadii.r99,
            ),
          ),
        ),
      ),
    );
  }

  Widget _named() => Semantics(
    container: true,
    label: 'Etapa ${current + 1} de $total: ${_names[current]}',
    excludeSemantics: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < total; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == total - 1 ? 0 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= current ? AppColors.primary : AppColors.line,
                      borderRadius: AppRadii.r99,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${i + 1}. ${_names[i]}',
                    style: AppTextStyles.caption.copyWith(
                      color: i == current
                          ? AppColors.primary
                          : i < current
                          ? AppColors.ink
                          : AppColors.muted,
                      fontWeight: i == current
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
