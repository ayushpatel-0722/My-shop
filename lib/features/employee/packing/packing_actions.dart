import 'package:flutter/foundation.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../core/domain/employee_roles.dart';
import '../../../core/domain/packing_workflow.dart';
import '../../../core/models/order.dart';
import '../../../core/services/service_locator.dart';

/// Set after an action so the dashboard opens (or switches to) the tab the
/// order moved to. The dashboard consumes and clears it.
final ValueNotifier<PackingStage?> requestedPackingStage =
    ValueNotifier<PackingStage?>(null);

/// Toast text for a finished action.
String packingActionDoneText(AppLocalizations l10n, PackingAction a) =>
    switch (a) {
      PackingAction.startPacking => l10n.empPackingStarted,
      PackingAction.markPacked => l10n.empMarkedReady,
      PackingAction.startDelivery => l10n.empDeliveryStarted,
      PackingAction.markDelivered => l10n.empDeliveredDone,
    };

String packingActionLabel(AppLocalizations l10n, PackingAction a) =>
    switch (a) {
      PackingAction.startPacking => l10n.empStartPacking,
      PackingAction.markPacked => l10n.empMarkPacked,
      PackingAction.startDelivery => l10n.empStartDelivery,
      PackingAction.markDelivered => l10n.empMarkDelivered,
    };

/// Performs [action] on [order] as employee [employeeId].
///
/// The action is re-checked against [PackingWorkflow] first, so a stale card
/// (the admin cancelled or moved the order meanwhile) or a missing
/// permission cannot skip a stage.
Future<void> performPackingAction(
  Order order,
  PackingAction action,
  String employeeId,
  EmployeeAccess access,
) async {
  if (PackingWorkflow.nextAction(order, employeeId, access) != action ||
      !PackingWorkflow.isLegalFor(order, action)) {
    throw StateError('Action $action is not allowed for ${order.id}');
  }
  await repo.updateOrderStatus(
    order.id,
    PackingWorkflow.targetStatus(action),
    companyId: order.companyId,
  );
}

/// A short, readable reason for a failed packing action, shown under the
/// generic "could not update" message so a failure is diagnosable.
String packingErrorDetail(Object error) {
  debugPrint('[Packing] action failed: $error');
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return 'Permission denied by Firestore rules. Your role may not allow '
        'this step, or the latest firestore.rules are not deployed yet.';
  }
  if (text.contains('Illegal order status transition') ||
      text.contains('is not allowed for')) {
    return 'The order was changed by someone else. Refresh and try again.';
  }
  if (text.contains('unavailable') || text.contains('network')) {
    return 'No connection. Check your internet and try again.';
  }
  final clean = text.replaceFirst(RegExp(r'^\w*(Exception|Error): '), '');
  return clean.length > 140 ? '${clean.substring(0, 140)}…' : clean;
}
