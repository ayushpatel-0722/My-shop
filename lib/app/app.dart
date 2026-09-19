import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/services/service_locator.dart';
import '../core/utils/force_update_gate.dart';
import 'l10n/app_localizations.dart';
import 'l10n/locale_cubit.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';

class App extends StatefulWidget {
  final LocaleCubit localeCubit;
  final List<BlocProvider> providers;
  final bool firebaseReady;

  const App({
    super.key,
    required this.localeCubit,
    required this.providers,
    required this.firebaseReady,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  /// Listens for `ecommerce://…` links and routes them to the correct screen
  /// (Section 15.2).
  void _initDeepLinks() {
    _deepLinkSub = deepLinks.stream.listen((uri) {
      final loc = deepLinks.toRoute(uri);
      if (loc != null) appRouter.push(loc);
    });
    deepLinks
        .getInitialLink()
        .then((uri) {
          if (uri != null) {
            final loc = deepLinks.toRoute(uri);
            if (loc != null) appRouter.push(loc);
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: widget.providers,
      child: BlocBuilder<LocaleCubit, Locale>(
        bloc: widget.localeCubit,
        builder: (context, locale) {
          final app = MaterialApp.router(
            title: 'Bazaar',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.light,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: appRouter,
            builder: (context, child) {
              return child ?? const SizedBox.shrink();
            },
          );
          return ForceUpdateGate(
            remoteConfig: widget.firebaseReady
                ? ServiceLocator.instance.remoteConfigService
                : null,
            child: app,
          );
        },
      ),
    );
  }
}

/// Re-export to keep imports tidy elsewhere.
const localizationsDelegates = AppLocalizations.localizationsDelegates;
const supportedLocales = AppLocalizations.supportedLocales;

const kFlutterDelegates = <dynamic>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
