import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:sail_ui/sail_ui.dart';
import 'package:sail_ui/shell/shell.dart';
import 'package:sidepot/gen/version.dart';
import 'package:sidepot/providers/game_provider.dart';
import 'package:sidepot/routing/router.dart';
import 'package:sidepot/widgets/homepage_widget_catalog.dart';

class SidepotModule extends SidechainModule {
  @override
  Sidechain get chain => Sidepot();

  @override
  String get appName => 'Sidepot';

  @override
  SidechainAppVersion get version => const SidechainAppVersion(
    version: AppVersion.version,
    versionString: AppVersion.versionString,
    buildDate: AppVersion.buildDate,
    commitFull: AppVersion.commitFull,
    appName: AppVersion.appName,
  );

  @override
  RootStackRouter registerRouter(GetIt getIt) {
    if (!getIt.isRegistered<AppRouter>()) {
      getIt.registerSingleton<AppRouter>(AppRouter());
    }
    return getIt.get<AppRouter>();
  }

  @override
  SidechainRPC registerRPC(GetIt getIt) {
    if (!getIt.isRegistered<SidepotRPC>()) {
      getIt.registerSingleton<SidepotRPC>(SidepotLive());
    }
    return getIt.get<SidepotRPC>();
  }

  @override
  Future<void> registerChainProviders(GetIt getIt, Directory applicationDir, Logger log) async {
    if (!getIt.isRegistered<GameProvider>()) {
      getIt.registerLazySingleton<GameProvider>(() => GameProvider(), dispose: (provider) => provider.dispose());
    }
  }

  @override
  Map<String, String> confPorts(String network) {
    switch (network) {
      case 'regtest':
        return {
          'rpc-addr': '127.0.0.1:16088',
          'net-addr': '0.0.0.0:14088',
          'mainchain-grpc-url': 'http://localhost:50051',
        };
      case 'mainnet':
        return {
          'rpc-addr': '127.0.0.1:26088',
          'net-addr': '0.0.0.0:24088',
          'mainchain-grpc-url': 'http://localhost:50051',
        };
      case 'signet':
      default:
        return {
          'rpc-addr': '127.0.0.1:6088',
          'net-addr': '0.0.0.0:4088',
          'mainchain-grpc-url': 'http://localhost:50051',
        };
    }
  }

  @override
  List<String> get defaultHomepageWidgets => [
    'game_card',
    'balance_card',
    'receive_card',
    'send_card',
    'sidepot_table',
    'utxo_table',
  ];

  @override
  Map<String, HomepageWidgetInfo> get widgetCatalog => SidepotWidgetCatalog.getCatalogMap();

  @override
  List<ShellTab> get tabs => const [
    ShellTab(label: 'Game', route: GameRoute(), sourceFiles: ['game_page.dart']),
  ];

  @override
  List<AutoRoute> get tabRoutes => [
    AutoRoute(page: GameRoute.page),
  ];
}
