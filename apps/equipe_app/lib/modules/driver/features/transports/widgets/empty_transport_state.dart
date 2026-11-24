import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppMessageState;

class EmptyTransportState extends StatelessWidget {
  const EmptyTransportState({
    super.key,
    required this.title,
    required this.message,
  });
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => AppMessageState(
    icon: Icons.route_outlined,
    title: title,
    message: message,
    center: true,
    padding: const EdgeInsets.all(30),
    messageGap: 7,
    mainAxisSize: MainAxisSize.min,
  );
}
