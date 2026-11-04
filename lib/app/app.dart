import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/services/deep_link_handler.dart';
import '../core/services/service_locator.dart';
import '../core/utils/force_update_gate.dart';
import '../core/widgets/cache_consent_prompt.dart';
import '../core/widgets/offline_banner.dart';
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
  late final DeepLinkHandler _deepLinkHandler;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  /// Opens `ecommerce://…` and https product / shop links on the right screen
  /// (Section 15.2), whether the app was closed, in the background or open.
  void _initDeepLinks() {
    _deepLinkHandler = DeepLinkHandler(
      service: deepLinks,
      navigate: (loc) => appRouter.push(loc),
      currentLocation: () =>
          appRouter.routerDelegate.currentConfiguration.uri.toString(),
    )..start();
  }

  @override
  void dispose() {
    _deepLinkHandler.dispose();
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
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.light,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: appRouter,
            builder: (context, child) {
              return CacheConsentPrompt(
                child: OfflineBanner(child: child ?? const SizedBox.shrink()),
              );
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
