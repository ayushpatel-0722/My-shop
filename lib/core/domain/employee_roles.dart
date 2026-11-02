/// Permission keys stored in `employees/{id}.permissions`.
class EmployeePermission {
  const EmployeePermission._();

  static const pack = 'canPack';
  static const dispatch = 'canDispatch';
  static const manageOrders = 'canManageOrders';

  static const all = <String>[pack, dispatch, manageOrders];
}

/// The three employee roles.
///
/// A role is a fixed bundle of permissions: the role picked in the admin form
/// *is* what the employee may do, so the permissions saved on the profile are
/// always derived from it. The app and the Firestore rules check the
/// permissions, never the title.
///
/// | Role            | Orders                         |
/// | --------------- | ------------------------------ |
/// | [manager]       | every status                   |
/// | [orderPacker]   | Order Confirmed -> Order Ready |
/// | [orderDelivery] | Order Ready -> Order Delivered |
///
/// Only the admin adds or edits employees; every role just sees the list.
enum EmployeeRole {
  manager('manager', {
    EmployeePermission.pack: true,
    EmployeePermission.dispatch: true,
    EmployeePermission.manageOrders: true,
  }),
  orderPacker('order_packer', {EmployeePermission.pack: true}),
  orderDelivery('order_delivery', {EmployeePermission.dispatch: true});

  /// Stable id stored in `employees/{id}.role`, independent of translations.
  final String id;
  final Map<String, bool> permissions;

  const EmployeeRole(this.id, this.permissions);

  /// Every key set explicitly so a role fully replaces the old switches.
  Map<String, bool> get fullPermissions => {
    for (final k in EmployeePermission.all) k: permissions[k] ?? false,
  };

  /// The role stored on a profile.
  ///
  /// Profiles created before roles were fixed hold a free-text designation
  /// ("Picker", "Dispatcher"...), so an unknown value falls back on what the
  /// saved permissions allow. Nothing legacy is ever promoted to manager.
  static EmployeeRole resolve(String? stored, Map<String, bool> permissions) {
    for (final r in values) {
      if (r.id == stored) return r;
    }
    final access = EmployeeAccess(permissions);
    if (access.canDispatch && !access.canPack) return orderDelivery;
    return orderPacker;
  }
}

/// Reads a permissions map from Firestore / the session cache.
Map<String, bool> parsePermissions(Object? raw) {
  if (raw is! Map) return const {};
  return {for (final e in raw.entries) e.key.toString(): e.value == true};
}

/// What a signed-in employee may do.
///
/// A profile that has never had permissions saved (an account created before
/// permissions existed) keeps the packing access it always had.
class EmployeeAccess {
  final Map<String, bool> _permissions;
  const EmployeeAccess(this._permissions);

  bool _has(String key) => _permissions.isEmpty
      ? key == EmployeePermission.pack
      : _permissions[key] == true;

  bool get canPack => _has(EmployeePermission.pack);
  bool get canDispatch => _has(EmployeePermission.dispatch);

  /// Manager: may move an order to any status, cancellation included.
  bool get canManageOrders =>
      _permissions[EmployeePermission.manageOrders] == true;

  /// True when the employee has a fulfilment screen to work in.
  bool get hasFulfilmentAccess => canPack || canDispatch || canManageOrders;
}

/// Which order buttons a signed-in person gets on the shared orders pipeline.
///
/// An admin and a manager may do everything the status rules allow; a packer
/// and a delivery employee only take the steps of their own role. The
/// Firestore rules enforce the same table.
class OrderPermissions {
  final bool _full;
  final EmployeeAccess _access;

  const OrderPermissions._(this._full, this._access);

  const OrderPermissions.admin() : this._(true, const EmployeeAccess({}));

  factory OrderPermissions.employee(EmployeeAccess access) =>
      OrderPermissions._(access.canManageOrders, access);

  /// Moving an order from [from] to [to] (cancelling included).
  bool canMove(String from, String to) {
    // Completing an order is the customer's review, never a button.
    if (to == 'completed') return false;
    if (_full) return true;
    return switch ((from, to)) {
      ('confirmed', 'packing') || ('packing', 'ready') => _access.canPack,
      ('ready', 'on_the_way') ||
      ('on_the_way', 'delivered') => _access.canDispatch,
      _ => false,
    };
  }

  bool get canCancel => _full;
  bool get canVerifyPayment => _full;
}
