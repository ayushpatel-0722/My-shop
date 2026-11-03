import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Which shopper tab is on screen (0 Home, 1 Categories, 2 Orders, 3 Account).
///
/// Tabs stay alive underneath each other, so a tab that is shown again must be
/// told it came back — that is the moment to refresh data that has gone stale.
class MarketplaceTabs {
  const MarketplaceTabs._();

  static const int home = 0;
  static const int categories = 1;
  static const int orders = 2;
  static const int account = 3;

  /// The visible tab; listeners are told on every change.
  static final ValueNotifier<int> active = ValueNotifier<int>(home);
}

/// The shell around the four shopper tabs.
///
/// go_router keeps every tab's screens alive in an indexed stack: switching
/// tabs only changes which one is visible. So a tab that was opened before
/// comes back at once, with its data, scroll position, search text and filters
/// — nothing is rebuilt or reloaded, which is what used to show a loader on
/// every tap.
class MarketplaceShell extends StatefulWidget {
  const MarketplaceShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<MarketplaceShell> createState() => _MarketplaceShellState();
}

class _MarketplaceShellState extends State<MarketplaceShell> {
  @override
  void initState() {
    super.initState();
    _publish();
  }

  @override
  void didUpdateWidget(MarketplaceShell old) {
    super.didUpdateWidget(old);
    _publish();
  }

  // After the frame: listeners may call setState, which is not allowed while
  // the tree is still being built.
  void _publish() {
    final index = widget.shell.currentIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (MarketplaceTabs.active.value != index) {
        MarketplaceTabs.active.value = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.shell;
}
