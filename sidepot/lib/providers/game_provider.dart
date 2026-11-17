import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:sail_ui/sail_ui.dart';

/// Keys one buy may take.
const maxKeysPerBuy = 1000;

/// Blocks on the clock when a round opens.
const roundStartBlocks = 144;

/// Reads the game from the node every few seconds and posts moves.
class GameProvider extends ChangeNotifier {
  static const _interval = Duration(seconds: 5);

  SidepotRPC get _rpc => GetIt.I.get<SidepotRPC>();

  GetGameStateResponse? state;
  GetGameAccountResponse? account;

  /// Why the last read failed, or null after a good one.
  String? error;

  Timer? _timer;
  bool _reading = false;
  bool _disposed = false;

  /// [poll] false reads the game once and then only on [refresh].
  GameProvider({bool poll = true}) {
    if (poll) {
      _timer = Timer.periodic(_interval, (_) => refresh());
    }
    unawaited(refresh());
  }

  /// The game as of the latest mainchain block.
  GameState? get game => state == null ? null : (state!.hasPreview() ? state!.preview : state!.confirmed);

  /// The account as of the latest mainchain block.
  GameAccount? get myAccount =>
      account == null ? null : (account!.hasPreview() ? account!.preview : account!.confirmed);

  /// True until the mainchain reaches the first block of the game.
  bool get notOpenYet {
    final g = game;
    return g != null && state!.startHeight > 0 && g.l1Height < state!.startHeight;
  }

  int get blocksLeft {
    final g = game;
    if (g == null) {
      return 0;
    }
    if (notOpenYet) {
      return roundStartBlocks;
    }
    final left = g.deadline - g.clock;
    return left < 0 ? 0 : left;
  }

  int get priceSats => game?.priceSats.toInt() ?? 0;

  /// The most one key can cost by the time a buy lapses: three price steps of 1%.
  int get maxPriceSats {
    var price = priceSats;
    for (var i = 0; i < 3; i++) {
      price = price * 101 ~/ 100;
    }
    return price;
  }

  int get jackpotSats => (game?.potSats.toInt() ?? 0) * 3 ~/ 4;

  Future<void> refresh() async {
    if (_reading || _disposed) {
      return;
    }
    _reading = true;
    try {
      final newState = await _rpc.getGameState();
      GetGameAccountResponse? newAccount;
      try {
        newAccount = await _rpc.getGameAccount();
      } catch (_) {
        // A wallet without a seed has no game account yet.
        newAccount = null;
      }
      state = newState;
      account = newAccount;
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      _reading = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<GameMoveResponse> buy(int keys) async {
    final move = await _rpc.gameBuy(keys);
    unawaited(refresh());
    return move;
  }

  Future<GameMoveResponse> cashout(int amountSats, {String dest = ''}) async {
    final move = await _rpc.gameCashout(amountSats, dest: dest);
    unawaited(refresh());
    return move;
  }

  Future<String> deposit(int valueSats, int feeSats) async {
    final txid = await _rpc.gameDeposit(valueSats, feeSats);
    unawaited(refresh());
    return txid;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
