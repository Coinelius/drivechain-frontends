# Patched fork — BitAssets client on eCash alphanet

This branch (`alphanet-fixes`) is [LayerTwo-Labs/drivechain-frontends](https://github.com/LayerTwo-Labs/drivechain-frontends)
at `381e683` with three commits that make the **BitAssets** client usable
against a real node. It is not a rewrite and touches five files.

Upstream `master` has moved past `381e683`; this branch stays on the commit the
fixes were built and tested on. `master` here tracks upstream untouched.

## What was broken

Every one of these failed **silently**, into a `catch` that discarded the
exception and left the UI blank. That is the single biggest problem in this
code: a malformed request, an unparseable response and an empty pool all look
identical on screen.

**The wallet always looked empty.** `BitAssetsUTXO.fromJson` cast the outpoint
to `String`, but an outpoint is an object keyed by kind (`Regular`,
`Coinbase`, `Deposit`). It threw on the first UTXO, so `listUTXOs` failed
wholesale. The base-coin balance still showed, because it comes from a separate
call — so the portfolio read "balance fine, 0 BitAssets", which is a misleading
place to start debugging.

**The AMM tab could never quote or swap.** The native coin was sent as `'btc'`
(not valid hex; an `AssetId` is `00`), BitAssets were sent without their `01`
tag (so the node read the id's first byte as a borsh enum tag — this broke
*every* pair), and the price response was read as `{base, quote}` when
`get_amm_price` returns `{"Rational":["Plus",[n,d]]}`.

**Amounts were labelled with the whole-coin ticker** while every value on the
page is in the smallest unit. A 5,000,000 szat / 5,000,000 BitAsset pool read
as "1 ECX = 1.000000 ALPHA"; it is 1 szat = 1 ALPHA. Off by 1e8, in the
direction that flatters the asset.

**The only holdings view was dead code.** `PortfolioDashboard` — holdings
table, allocation chart, asset count — was referenced nowhere and rendered by
nothing. It is now a `portfolio` entry in the homepage widget catalog: open
**Configure Homepage** (top right, beside the network dropdown) → **Add
Widget** → **Portfolio**.

## Known-not-fixed

- **Allocation percentages are meaningless.** `totalValue` sums BitAsset units
  and LP tokens straight into a base-unit total with no price conversion. The
  amounts are correct; the pie chart is not.
- **Nothing shows pending transactions.** `myUnconfirmedUtxos()` exists in the
  RPC client and no caller uses it, so a submitted swap is invisible until it
  confirms — up to ~30 minutes on alphanet.
- **`bitnames/`** uses the same bare-hash dropdown pattern and likely carries
  the `AssetId` tagging bug too. Not audited.

## The node must be patched too

These fixes assume a node from
[Coinelius/plain-bitassets](https://github.com/Coinelius/plain-bitassets),
which carries five fixes of its own — without them no AMM pool can be created,
no swap returns a correct payout, and deposits credit an unspendable address.
Two of those are consensus changes, so every node on the chain must run the
same side of them.

BitWindow downloads *upstream* BitAssets into
`~/.local/share/bitwindow/assets/bin/`, so the built binaries have to be copied
over what it fetches.
