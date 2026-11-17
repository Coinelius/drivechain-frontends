import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:sail_ui/sail_ui.dart';
import 'package:sidepot/providers/game_provider.dart';

/// The mainchain fee of a deposit from this screen, in sats.
const _depositFeeSats = 1000;

@RoutePage()
class GamePage extends StatelessWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<GameViewModel>.reactive(
      viewModelBuilder: () => GameViewModel(),
      builder: (context, model, child) {
        return QtPage(
          child: SingleChildScrollView(
            child: SailColumn(
              spacing: SailStyleValues.padding16,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (model.notice != null) SailCard(child: SailText.primary13(model.notice!)),
                SailRow(
                  spacing: SailStyleValues.padding16,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _PotCard(model: model)),
                    Expanded(child: _ClockCard(model: model)),
                  ],
                ),
                SailRow(
                  spacing: SailStyleValues.padding16,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _BuyCard(model: model)),
                    Expanded(child: _AccountCard(model: model)),
                  ],
                ),
                SailRow(
                  spacing: SailStyleValues.padding16,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _AddFundsCard(model: model)),
                    Expanded(child: _CashOutCard(model: model)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PotCard extends StatelessWidget {
  final GameViewModel model;

  const _PotCard({required this.model});

  @override
  Widget build(BuildContext context) {
    return SailCard(
      title: model.loaded ? 'Round ${model.round} pot' : 'Pot',
      child: SailColumn(
        spacing: SailStyleValues.padding08,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SailSkeletonizer(
            enabled: !model.loaded,
            description: 'Waiting for the Sidepot node...',
            child: SailText.primary40(model.pot, bold: true),
          ),
          SailText.secondary13(
            'The last block of buyers splits ${model.jackpot}. The rest opens the next round.',
          ),
        ],
      ),
    );
  }
}

class _ClockCard extends StatelessWidget {
  final GameViewModel model;

  const _ClockCard({required this.model});

  @override
  Widget build(BuildContext context) {
    final left = model.blocksLeft;
    return SailCard(
      title: 'Clock',
      child: SailColumn(
        spacing: SailStyleValues.padding08,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SailSkeletonizer(
            enabled: !model.loaded,
            description: 'Waiting for the Sidepot node...',
            child: SailText.primary40('$left ${left == 1 ? 'block' : 'blocks'} left', bold: true),
          ),
          SailText.secondary13(
            'Every buy puts at least 6 blocks back on the clock. Empty mainchain blocks do not count.',
          ),
          _Fact(label: 'Price per key', value: model.price),
          _Fact(label: 'Bonus pool', value: model.bonusPool),
          _Fact(label: 'Shown as of mainchain block', value: model.previewHeight),
          _Fact(label: 'Final up to mainchain block', value: model.finalHeight),
        ],
      ),
    );
  }
}

class _BuyCard extends StatelessWidget {
  final GameViewModel model;

  const _BuyCard({required this.model});

  @override
  Widget build(BuildContext context) {
    return SailCard(
      title: 'Buy keys',
      error: model.buyError,
      child: SailColumn(
        spacing: SailStyleValues.padding08,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          NumericField(
            label: 'Keys (1 to $maxKeysPerBuy)',
            controller: model.keysController,
            hintText: '1',
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          _Fact(label: 'Cost now', value: model.costNow),
          _Fact(label: 'At most', value: model.costAtMost),
          SailText.secondary12(
            'The price rises 1% after each block with a buy. If it passes the limit, or three counted blocks go by, '
            'the buy lapses and costs only the mainchain fee.',
          ),
          SailButton(
            label: model.buyLabel,
            disabled: !model.canBuy,
            loading: model.buying,
            onPressed: model.buy,
          ),
          if (model.buyResult != null) SailText.secondary13(model.buyResult!),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final GameViewModel model;

  const _AccountCard({required this.model});

  @override
  Widget build(BuildContext context) {
    return SailCard(
      title: 'Your game account',
      child: SailColumn(
        spacing: SailStyleValues.padding08,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Fact(label: 'Balance', value: model.balance),
          _Fact(label: 'Keys this round', value: model.keys),
          SailTextField(
            label: 'Deposit address',
            controller: model.addressController,
            hintText: 'This wallet has no game account yet',
            readOnly: true,
            suffixWidget: CopyButton(text: model.address),
          ),
          SailText.secondary12(
            'A deposit to this address from any mainchain wallet lands in the game account, not in the sidechain wallet.',
          ),
        ],
      ),
    );
  }
}

class _AddFundsCard extends StatelessWidget {
  final GameViewModel model;

  const _AddFundsCard({required this.model});

  @override
  Widget build(BuildContext context) {
    return SailCard(
      title: 'Add funds',
      error: model.depositError,
      child: SailColumn(
        spacing: SailStyleValues.padding08,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SailText.secondary13(
            'Moves coins from the mainchain wallet into the game account. It shows as soon as a mainchain block includes it.',
          ),
          NumericField(label: 'Amount', controller: model.depositController, hintText: '0.00'),
          SailButton(
            label: 'Add funds',
            disabled: !model.canDeposit,
            loading: model.depositing,
            onPressed: model.deposit,
          ),
          if (model.depositResult != null) SailText.secondary13(model.depositResult!),
        ],
      ),
    );
  }
}

class _CashOutCard extends StatelessWidget {
  final GameViewModel model;

  const _CashOutCard({required this.model});

  @override
  Widget build(BuildContext context) {
    return SailCard(
      title: 'Cash out',
      error: model.cashoutError,
      child: SailColumn(
        spacing: SailStyleValues.padding08,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SailText.secondary13(
            'Pays from the game account to a coin in the sidechain wallet. Moving it on to the mainchain is a withdrawal, which is slow.',
          ),
          NumericField(label: 'Amount', controller: model.cashoutController, hintText: 'All of it'),
          SailTextField(
            label: 'To',
            controller: model.cashoutDestController,
            hintText: 'A new address of this wallet',
          ),
          SailButton(
            label: 'Cash out',
            disabled: !model.canCashout,
            loading: model.cashingOut,
            onPressed: model.cashout,
          ),
          if (model.cashoutResult != null) SailText.secondary13(model.cashoutResult!),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;

  const _Fact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SailRow(
      spacing: SailStyleValues.padding08,
      children: [
        Expanded(child: SailText.secondary13(label)),
        SailText.primary13(value, monospace: true),
      ],
    );
  }
}

class GameViewModel extends BaseViewModel {
  final GameProvider _game = GetIt.I.get<GameProvider>();
  final FormatterProvider _formatter = GetIt.I.get<FormatterProvider>();
  final SyncProvider _sync = GetIt.I.get<SyncProvider>();

  final keysController = TextEditingController(text: '1');
  final depositController = TextEditingController();
  final cashoutController = TextEditingController();
  final cashoutDestController = TextEditingController();
  final addressController = TextEditingController();

  bool buying = false;
  bool depositing = false;
  bool cashingOut = false;
  String? buyResult;
  String? buyError;
  String? depositResult;
  String? depositError;
  String? cashoutResult;
  String? cashoutError;

  GameViewModel() {
    _game.addListener(_onChange);
    _formatter.addListener(notifyListeners);
    for (final controller in [keysController, depositController, cashoutController]) {
      controller.addListener(notifyListeners);
    }
    _onChange();
  }

  void _onChange() {
    final address = _game.account?.address ?? '';
    if (addressController.text != address) {
      addressController.text = address;
    }
    notifyListeners();
  }

  bool get loaded => _game.game != null;

  /// What to say above the game, if anything.
  String? get notice {
    if (_game.error != null && !loaded) {
      return 'The Sidepot node does not answer yet: ${_game.error}';
    }
    if (!_game.notOpenYet) {
      return null;
    }
    final start = _game.state!.startHeight;
    final tip = _sync.mainchainSyncInfo?.progressCurrent.toInt() ?? 0;
    final wait = tip > 0 && tip < start ? ', ${start - tip} ${start - tip == 1 ? 'block' : 'blocks'} from now' : '';
    return 'The game opens at mainchain block $start$wait. Funds can be added already; buys before that block do not count.';
  }

  String _sats(Object? sats) => _formatter.formatSats(int.parse((sats ?? 0).toString()));

  int get round => _game.game?.round ?? 0;
  String get pot => _sats(_game.game?.potSats);
  String get jackpot => _sats(_game.jackpotSats);
  int get blocksLeft => _game.blocksLeft;
  String get price => _sats(_game.priceSats);
  String get bonusPool => _sats(_game.game?.bonusPoolSats);
  String get previewHeight => loaded ? '${_game.game!.l1Height}' : '-';
  String get finalHeight => loaded ? '${_game.state!.confirmed.l1Height}' : '-';
  String get balance => _sats(_game.myAccount?.balanceSats);
  String get keys => '${_game.myAccount?.keys ?? 0}';
  String get address => _game.account?.address ?? '';

  int get keysWanted => int.tryParse(keysController.text) ?? 0;
  bool get _keysValid => keysWanted >= 1 && keysWanted <= maxKeysPerBuy;
  String get costNow => _keysValid ? _sats(_game.priceSats * keysWanted) : '-';
  String get costAtMost => _keysValid ? _sats(_game.maxPriceSats * keysWanted) : '-';

  String get buyLabel {
    if (_game.notOpenYet) {
      return 'Not open yet';
    }
    return _keysValid ? 'Buy $keysWanted ${keysWanted == 1 ? 'key' : 'keys'}' : 'Buy keys';
  }

  bool get canBuy => loaded && !_game.notOpenYet && _keysValid && !buying;

  /// Sats of a typed coin amount, or null when it is not a positive number.
  int? _amountSats(String text) {
    final amount = double.tryParse(text.trim());
    if (amount == null || amount <= 0) {
      return null;
    }
    return btcToSatoshi(amount).toInt();
  }

  bool get canDeposit => address.isNotEmpty && _amountSats(depositController.text) != null && !depositing;

  /// An empty amount cashes out everything.
  bool get canCashout =>
      address.isNotEmpty &&
      (cashoutController.text.trim().isEmpty || _amountSats(cashoutController.text) != null) &&
      !cashingOut;

  String _short(String txid) => txid.length > 12 ? '${txid.substring(0, 12)}…' : txid;

  Future<void> buy() async {
    buying = true;
    buyError = null;
    buyResult = null;
    notifyListeners();
    try {
      final keys = keysWanted;
      final move = await _game.buy(keys);
      buyResult =
          'Sent a buy of $keys ${keys == 1 ? 'key' : 'keys'} for round ${move.round} in mainchain transaction ${_short(move.txid)}. It counts once a block includes it.';
    } catch (e) {
      buyError = 'The buy was not sent: $e';
    } finally {
      buying = false;
      notifyListeners();
    }
  }

  Future<void> deposit() async {
    final sats = _amountSats(depositController.text);
    if (sats == null) {
      return;
    }
    depositing = true;
    depositError = null;
    depositResult = null;
    notifyListeners();
    try {
      final txid = await _game.deposit(sats, _depositFeeSats);
      depositResult =
          'Sent ${_sats(sats)} in mainchain transaction ${_short(txid)}. It shows once a block includes it.';
      depositController.clear();
    } catch (e) {
      depositError = 'The deposit was not sent: $e';
    } finally {
      depositing = false;
      notifyListeners();
    }
  }

  Future<void> cashout() async {
    final typed = cashoutController.text.trim();
    final sats = typed.isEmpty ? 0 : _amountSats(typed);
    if (sats == null) {
      return;
    }
    cashingOut = true;
    cashoutError = null;
    cashoutResult = null;
    notifyListeners();
    try {
      final move = await _game.cashout(sats, dest: cashoutDestController.text.trim());
      cashoutResult =
          'Sent a cashout of ${sats == 0 ? 'the whole balance' : _sats(sats)} in mainchain transaction ${_short(move.txid)}. The coin arrives a few blocks after a block includes it.';
      cashoutController.clear();
    } catch (e) {
      cashoutError = 'The cashout was not sent: $e';
    } finally {
      cashingOut = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _game.removeListener(_onChange);
    _formatter.removeListener(notifyListeners);
    keysController.dispose();
    depositController.dispose();
    cashoutController.dispose();
    cashoutDestController.dispose();
    addressController.dispose();
    super.dispose();
  }
}
