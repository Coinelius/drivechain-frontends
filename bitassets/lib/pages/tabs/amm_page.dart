import 'package:auto_route/auto_route.dart';
import 'package:bitassets/providers/bitassets_provider.dart';
import 'package:bitassets/settings/amm_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:sail_ui/sail_ui.dart';
import 'package:stacked/stacked.dart';

@RoutePage()
class AmmTabPage extends StatelessWidget {
  const AmmTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return QtPage(
      child: ViewModelBuilder<AmmSwapViewModel>.reactive(
        viewModelBuilder: () => AmmSwapViewModel(),
        builder: (context, model, child) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SailCard(
                title: 'Swap',
                subtitle: 'Trade BitAssets',
                error: model.swapError,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    SailColumn(
                      spacing: SailStyleValues.padding08,
                      children: [
                        // Asset to spend
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SailText.primary13('You pay'),
                            const SizedBox(height: 4),
                            SailRow(
                              spacing: SailStyleValues.padding08,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: SailDropdownButton<String>(
                                    value: model.assetSpend,
                                    items: model.assetOptions,
                                    onChanged: (value) => model.setAssetSpend(value),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: SailTextField(
                                    hintText: '0',
                                    controller: model.amountSpendController,
                                    suffix: model.assetSpend.isEmpty ? activeTicker.subunit : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Swap direction button
                        Center(
                          child: SailTooltip(
                            message: 'Swap direction',
                            child: SailButton(
                              variant: ButtonVariant.icon,
                              icon: SailSVGAsset.iconArrow,
                              iconWidth: 24,
                              onPressed: () async => model.swapAssets(),
                            ),
                          ),
                        ),

                        // Asset to receive
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SailText.primary13('You receive (estimated)'),
                            const SizedBox(height: 4),
                            SailRow(
                              spacing: SailStyleValues.padding08,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: SailDropdownButton<String>(
                                    value: model.assetReceive,
                                    items: model.assetOptions,
                                    onChanged: (value) => model.setAssetReceive(value),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: SailTextField(
                                    hintText: '0',
                                    controller: model.amountReceiveController,
                                    readOnly: true,
                                    suffix: model.assetReceive.isEmpty ? activeTicker.subunit : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Price info
                        if (model.priceInfo != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.sailTheme.colors.backgroundSecondary,
                              borderRadius: SailStyleValues.borderRadius,
                            ),
                            child: SailColumn(
                              spacing: SailStyleValues.padding08,
                              children: [
                                SailRow(
                                  spacing: SailStyleValues.padding08,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    SailText.secondary13('Rate'),
                                    SailText.primary13(model.priceInfo!, monospace: true),
                                  ],
                                ),
                                if (model.feeEstimate != null)
                                  SailRow(
                                    spacing: SailStyleValues.padding08,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      SailText.secondary13('Swap Fee (0.3%)'),
                                      SailText.primary13(
                                        '~${model.feeEstimate} ${activeTicker.subunit}',
                                        monospace: true,
                                      ),
                                    ],
                                  ),
                                if (model.minimumReceived != null)
                                  SailRow(
                                    spacing: SailStyleValues.padding08,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      SailText.secondary13('Min. received (${model.slippageTolerance}% slippage)'),
                                      SailText.primary13('~${model.minimumReceived}', monospace: true),
                                    ],
                                  ),
                              ],
                            ),
                          ),

                        // Advanced settings
                        SailCollapsible(
                          trigger: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: SailText.secondary13('Advanced Settings'),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: context.sailTheme.colors.backgroundSecondary,
                                    borderRadius: SailStyleValues.borderRadius,
                                  ),
                                  child: SailColumn(
                                    spacing: SailStyleValues.padding08,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SailText.secondary12('Slippage Tolerance'),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _SlippageButton(
                                            value: 0.1,
                                            selected: model.slippageTolerance == 0.1,
                                            onTap: () => model.setSlippage(0.1),
                                          ),
                                          _SlippageButton(
                                            value: 0.5,
                                            selected: model.slippageTolerance == 0.5,
                                            onTap: () => model.setSlippage(0.5),
                                          ),
                                          _SlippageButton(
                                            value: 1.0,
                                            selected: model.slippageTolerance == 1.0,
                                            onTap: () => model.setSlippage(1.0),
                                          ),
                                          _SlippageButton(
                                            value: 2.0,
                                            selected: model.slippageTolerance == 2.0,
                                            onTap: () => model.setSlippage(2.0),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),
                    const SizedBox(height: 16),

                    // Swap button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: model.canSwap
                              ? context.sailTheme.colors.primary
                              : context.sailTheme.colors.primary.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: model.canSwap
                              ? [
                                  BoxShadow(
                                    color: context.sailTheme.colors.shadow,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: SailTappable(
                          onTap: model.canSwap && !model.swapLoading ? () async => model.executeSwap(context) : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (model.swapLoading)
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: LoadingIndicator(
                                      color: context.sailTheme.colors.primaryButtonText,
                                    ),
                                  ),
                                ),
                              SailText.primary15(
                                model.swapLoading ? 'Swapping...' : 'Swap',
                                color: context.sailTheme.colors.primaryButtonText,
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SlippageButton extends StatelessWidget {
  final double value;
  final bool selected;
  final VoidCallback onTap;

  const _SlippageButton({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SailTheme.of(context);

    return SailTappable(
      onTap: () async => onTap(),
      borderRadius: SailStyleValues.borderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? theme.colors.primary : theme.colors.backgroundSecondary,
          borderRadius: SailStyleValues.borderRadius,
          border: Border.all(
            color: selected ? theme.colors.primary : theme.colors.divider,
          ),
        ),
        child: SailText.primary12(
          '$value%',
          color: selected ? theme.colors.primaryButtonText : null,
        ),
      ),
    );
  }
}

class AmmSwapViewModel extends BaseViewModel {
  final BitAssetsRPC rpc = GetIt.I.get<BitAssetsRPC>();
  final BitAssetsProvider bitAssetsProvider = GetIt.I.get<BitAssetsProvider>();
  final NotificationProvider notificationProvider = GetIt.I.get<NotificationProvider>();
  final ClientSettings _settings = GetIt.I.get<ClientSettings>();

  final TextEditingController amountSpendController = TextEditingController();
  final TextEditingController amountReceiveController = TextEditingController();

  String assetSpend = ''; // empty string = BTC
  String assetReceive = '';
  String? swapError;
  String? priceInfo;
  bool swapLoading = false;
  double slippageTolerance = 0.5;

  AmmSwapViewModel() {
    bitAssetsProvider.addListener(notifyListeners);
    bitAssetsProvider.fetch();
    amountSpendController.addListener(_onAmountChanged);
    _loadSlippage();
  }

  Future<void> _loadSlippage() async {
    final setting = await _settings.getValue(SlippageToleranceSetting());
    slippageTolerance = setting.value;
    notifyListeners();
  }

  void setSlippage(double value) {
    slippageTolerance = value;
    _settings.setValue(SlippageToleranceSetting(newValue: value));
    notifyListeners();
  }

  int? get feeEstimate {
    final amount = int.tryParse(amountSpendController.text);
    if (amount == null || amount <= 0) return null;
    return (amount * 0.003).round();
  }

  String? get minimumReceived {
    final receiveAmount = int.tryParse(amountReceiveController.text);
    if (receiveAmount == null || receiveAmount <= 0) return null;
    final minAmount = (receiveAmount * (1 - slippageTolerance / 100)).round();
    return minAmount.toString();
  }

  List<SailDropdownItem<String>> get assetOptions {
    final options = <SailDropdownItem<String>>[
      SailDropdownItem(value: '', label: '${activeTicker.symbol} (Native)'),
    ];

    for (final entry in bitAssetsProvider.entries) {
      final label = entry.plaintextName ?? entry.hash.substring(0, 12);
      options.add(SailDropdownItem(value: entry.hash, label: label));
    }

    return options;
  }

  bool get canSwap {
    if (assetSpend == assetReceive) return false;
    final amount = int.tryParse(amountSpendController.text);
    return amount != null && amount > 0;
  }

  void setAssetSpend(String? value) {
    if (value == null) return;
    assetSpend = value;
    _updatePrice();
    notifyListeners();
  }

  void setAssetReceive(String? value) {
    if (value == null) return;
    assetReceive = value;
    _updatePrice();
    notifyListeners();
  }

  void swapAssets() {
    final temp = assetSpend;
    assetSpend = assetReceive;
    assetReceive = temp;

    final tempAmount = amountSpendController.text;
    amountSpendController.text = amountReceiveController.text;
    amountReceiveController.text = tempAmount;

    _updatePrice();
    notifyListeners();
  }

  void _onAmountChanged() {
    _updatePrice();
  }

  Future<void> _updatePrice() async {
    if (assetSpend == assetReceive) {
      priceInfo = null;
      amountReceiveController.text = '';
      notifyListeners();
      return;
    }

    try {
      final price = await rpc.getAmmPrice(
        base: _assetId(assetSpend),
        quote: _assetId(assetReceive),
      );

      final rate = _parsePrice(price);
      if (rate != null) {
        priceInfo =
            '1 ${_assetLabel(assetSpend)} = ${rate.toStringAsFixed(6)} ${_assetLabel(assetReceive)}';

        // Update estimated receive amount
        final spendAmount = int.tryParse(amountSpendController.text);
        if (spendAmount != null && spendAmount > 0) {
          amountReceiveController.text =
              (spendAmount * rate).round().toString();
        }
      } else {
        priceInfo = 'No liquidity pool exists for this pair';
        amountReceiveController.text = '';
      }
    } catch (e) {
      // Silence here is expensive: a malformed request or an unparseable
      // response looks exactly like an empty pool, with nothing on screen to
      // say otherwise.
      priceInfo = 'Price unavailable: $e';
      amountReceiveController.text = '';
    }
    notifyListeners();
  }

  /// The RPC takes a borsh-encoded `AssetId` as hex: `00` for the native coin,
  /// and `01` followed by the id for a BitAsset. The dropdown carries the bare
  /// BitAsset hash (empty string for native), which `_assetLabel` and the
  /// provider both key on, so convert only here at the RPC boundary. Sending
  /// the bare hash makes the node read its first byte as the borsh enum tag
  /// ("unexpected variant tag: 144" for an id starting 90), and the old 'btc'
  /// placeholder is not valid hex at all.
  String _assetId(String dropdownValue) =>
      dropdownValue.isEmpty ? '00' : '01$dropdownValue';

  /// `get_amm_price` returns the reserve ratio as a serialised Rust
  /// `Fraction` - `{"Rational":["Plus",[numer,denom]]}` - or null when the
  /// pair has no pool. It carries no 'base'/'quote' keys. The node orients it
  /// as the price of `base` in terms of `quote`, so it is the multiplier for
  /// the spend amount directly.
  double? _parsePrice(Map<String, dynamic>? price) {
    final rational = price?['Rational'];
    if (rational is! List || rational.length != 2) return null;
    final parts = rational[1];
    if (parts is! List || parts.length != 2) return null;
    final numer = parts[0];
    final denom = parts[1];
    if (numer is! num || denom is! num || denom == 0) return null;
    final magnitude = numer.toDouble() / denom.toDouble();
    return rational[0] == 'Minus' ? -magnitude : magnitude;
  }

  String _assetLabel(String assetId) {
    // The subunit, not the symbol: amounts here are always the smallest unit,
    // whatever the display setting says, because that is what the RPC takes
    // and what the pool reserves are denominated in.
    if (assetId.isEmpty) return activeTicker.subunit;
    final entry = bitAssetsProvider.entries.where((e) => e.hash == assetId).firstOrNull;
    return entry?.plaintextName ?? assetId.substring(0, 8);
  }

  Future<void> executeSwap(BuildContext context) async {
    swapError = null;
    swapLoading = true;
    notifyListeners();

    try {
      final amountSpend = int.parse(amountSpendController.text);

      final amountReceived = await rpc.ammSwap(
        assetSpend: _assetId(assetSpend),
        assetReceive: _assetId(assetReceive),
        amountSpend: amountSpend,
      );

      if (context.mounted) {
        notificationProvider.add(
          title: 'Swap Successful',
          content: 'Received $amountReceived ${_assetLabel(assetReceive)}',
          dialogType: DialogType.success,
        );
      }

      // Clear form
      amountSpendController.clear();
      amountReceiveController.clear();
    } catch (e) {
      swapError = e.toString();
    } finally {
      swapLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    amountSpendController.removeListener(_onAmountChanged);
    amountSpendController.dispose();
    amountReceiveController.dispose();
    bitAssetsProvider.removeListener(notifyListeners);
    super.dispose();
  }
}
