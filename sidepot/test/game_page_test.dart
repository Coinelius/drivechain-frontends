import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sail_ui/sail_ui.dart';
import 'package:sidechain_core/mocks/mocks.dart';
import 'package:sidepot/pages/game_page.dart';
import 'package:sidepot/providers/game_provider.dart';

import 'test_utils.dart';

/// A node whose game the test sets.
class _GameRPC extends MockSidepotRPC {
  GetGameStateResponse state = GetGameStateResponse();
  int? boughtKeys;
  Object? buyFails;

  @override
  Future<GetGameStateResponse> getGameState() async => state;

  @override
  Future<GetGameAccountResponse> getGameAccount() async => GetGameAccountResponse(
    key: 'ab' * 32,
    address: 'spot:${'ab' * 32}',
    confirmed: GameAccount(balanceSats: Int64(50000000)),
    preview: GameAccount(balanceSats: Int64(47000000), keys: Int64(3), nonce: Int64(1)),
  );

  @override
  Future<GameMoveResponse> gameBuy(int keys) async {
    if (buyFails != null) {
      throw buyFails!;
    }
    boughtKeys = keys;
    return GameMoveResponse(
      txid: '946554659b3f9bf15f8ccf30887135bce13e6346',
      round: 20,
      nonce: Int64(2),
      expires: 2800,
    );
  }
}

GameState _game({required int l1Height, int clock = 2797, int deadline = 2832}) => GameState(
  l1Height: l1Height,
  clock: clock,
  round: 20,
  deadline: deadline,
  priceSats: Int64(1010000),
  potSats: Int64(2250000),
  bonusPoolSats: Int64(330109),
  accounts: 13,
);

Future<void> _loadFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final rpc = _GameRPC();

  setUpAll(() async {
    await _loadFonts();
    GetIt.I.registerSingleton<SidepotRPC>(rpc);
    GetIt.I.registerSingleton<SyncProvider>(MockSyncProvider());
  });

  setUp(() {
    rpc.boughtKeys = null;
    rpc.buyFails = null;
  });

  Future<void> pumpGame(WidgetTester tester) async {
    final game = GameProvider(poll: false);
    GetIt.I.registerSingleton<GameProvider>(game);
    addTearDown(() {
      game.dispose();
      GetIt.I.unregister<GameProvider>();
    });
    await tester.pumpSailPage(const GamePage());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('shows the game as of the latest mainchain block', (tester) async {
    rpc.state = GetGameStateResponse(
      confirmed: _game(l1Height: 7454, clock: 2795),
      preview: _game(l1Height: 7456),
      startHeight: 4735,
    );
    await pumpGame(tester);

    expect(find.text('Round 20 pot'), findsOneWidget);
    expect(find.text('35 blocks left'), findsOneWidget);
    expect(find.text('Buy 1 key'), findsWidgets);
    expect(find.textContaining('opens at mainchain block'), findsNothing);
    expect(find.text('3'), findsOneWidget, reason: 'keys held, from the preview');

    if (autoUpdateGoldenFiles) {
      await tester.pump(const Duration(seconds: 5));
      await expectLater(find.byType(GamePage), matchesGoldenFile('goldens/game_page.png'));
    }
  });

  testWidgets('a buy sends the typed number of keys and says what was sent', (tester) async {
    rpc.state = GetGameStateResponse(
      confirmed: _game(l1Height: 7454),
      preview: _game(l1Height: 7456),
      startHeight: 4735,
    );
    await pumpGame(tester);

    await tester.enterText(find.widgetWithText(SailTextField, '1').first, '5');
    await tester.pump();
    expect(find.text('Buy 5 keys'), findsWidgets);

    await tester.tap(find.widgetWithText(SailButton, 'Buy 5 keys').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(rpc.boughtKeys, 5);
    expect(find.textContaining('Sent a buy of 5 keys for round 20'), findsOneWidget);
  });

  testWidgets('a buy the node refuses shows why', (tester) async {
    rpc.state = GetGameStateResponse(
      confirmed: _game(l1Height: 7454),
      preview: _game(l1Height: 7456),
      startHeight: 4735,
    );
    rpc.buyFails = Exception('the game account holds too little');
    await pumpGame(tester);

    await tester.tap(find.widgetWithText(SailButton, 'Buy 1 key').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('The buy was not sent'), findsOneWidget);
    expect(find.textContaining('holds too little'), findsOneWidget);
  });

  testWidgets('takes no buys before the first block of the game', (tester) async {
    rpc.state = GetGameStateResponse(
      confirmed: _game(l1Height: 984959, clock: 0, deadline: 145),
      preview: _game(l1Height: 984959, clock: 0, deadline: 145),
      startHeight: 984960,
    );
    await pumpGame(tester);

    expect(find.textContaining('The game opens at mainchain block 984960'), findsOneWidget);
    expect(find.text('144 blocks left'), findsOneWidget);
    expect(find.text('Not open yet'), findsWidgets);
    await tester.tap(find.widgetWithText(SailButton, 'Not open yet').first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(rpc.boughtKeys, isNull);

    if (autoUpdateGoldenFiles) {
      await tester.pump(const Duration(seconds: 5));
      await expectLater(find.byType(GamePage), matchesGoldenFile('goldens/game_page_not_open.png'));
    }
  });
}
