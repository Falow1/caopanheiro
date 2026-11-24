import 'package:flutter/widgets.dart';
import 'workforce_controller.dart';

class WorkforceScope extends InheritedNotifier<WorkforceController> {
  const WorkforceScope({
    super.key,
    required WorkforceController controller,
    required super.child,
  }) : super(notifier: controller);
  static WorkforceController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkforceScope>()?.notifier;
  static WorkforceController of(BuildContext context) => maybeOf(context)!;
}
