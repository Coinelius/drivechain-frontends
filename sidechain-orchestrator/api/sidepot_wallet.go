package api

import (
	"context"
	"encoding/hex"
	"fmt"
	"regexp"

	"connectrpc.com/connect/v2"

	orchestrator "github.com/LayerTwo-Labs/sidesail/sidechain-orchestrator"
	wpb "github.com/LayerTwo-Labs/sidesail/sidechain-orchestrator/gen/walletmanager/v1"
	"github.com/LayerTwo-Labs/sidesail/sidechain-orchestrator/wallet"
)

// SidepotWallet carries Sidepot's game moves and deposits from the active
// wallet. Sidepot's moves are mainchain transactions, so they are paid from
// the same coins in full and in light mode.
type SidepotWallet struct {
	h *WalletHandler
}

func NewSidepotWallet(h *WalletHandler) *SidepotWallet {
	return &SidepotWallet{h: h}
}

// SendData broadcasts a transaction with one zero-value OP_RETURN output that
// holds the data in a single push.
func (w *SidepotWallet) SendData(ctx context.Context, dataHex string, feeSats int64) (string, error) {
	data, err := hex.DecodeString(dataHex)
	if err != nil || len(data) == 0 {
		return "", connect.Errorf(connect.CodeInvalidArgument, "a game move must be hex data")
	}
	send, err := w.h.SendTransaction(ctx, &wpb.SendTransactionRequest{
		OpReturnHex:  dataHex,
		FixedFeeSats: feeSats,
	})
	if err != nil {
		return "", err
	}
	return send.Txid, nil
}

// gameAccountAddress is a Sidepot game account as a deposit names it. It is
// not a sidechain address: the game credits the account when it reads the
// deposit's mainchain block.
var gameAccountAddress = regexp.MustCompile(`^spot:[0-9a-f]{64}$`)

// Deposit broadcasts a BIP300 deposit request to the slot for a game account.
// It is CreateDeposit with the one destination form that method refuses.
func (w *SidepotWallet) Deposit(
	ctx context.Context, slot uint8, destination string, amountSats, feeSats int64,
) (string, error) {
	h := w.h
	if amountSats <= 0 {
		return "", connect.Errorf(connect.CodeInvalidArgument, "amount_sats must be positive")
	}
	if feeSats <= 0 {
		return "", connect.Errorf(connect.CodeInvalidArgument, "fee_sats must be positive")
	}
	if !gameAccountAddress.MatchString(destination) {
		return "", connect.Errorf(connect.CodeInvalidArgument, "a game account is spot: and 64 hex digits")
	}
	if err := h.requireEngine(); err != nil {
		return "", connect.NewError(connect.CodeFailedPrecondition, err.Error()).WithCause(err)
	}
	walletID, err := h.engine.ResolveWalletID("")
	if err != nil {
		return "", connect.NewError(connect.CodeInvalidArgument, err.Error()).WithCause(err)
	}
	if err := h.requireActiveSlot(ctx, uint32(slot)); err != nil {
		return "", err
	}
	send, err := h.SendTransaction(ctx, &wpb.SendTransactionRequest{
		RawOutputs:   []*wpb.RawOutput{{ValueSats: amountSats, ScriptHex: hex.EncodeToString(orchestrator.M8TreasuryScript(slot))}},
		OpReturnHex:  hex.EncodeToString([]byte(destination)),
		FixedFeeSats: feeSats,
	})
	if err != nil {
		return "", err
	}
	// The broadcast already happened, so a failed record must not fail the call.
	if err := h.recordDeposit(ctx, wallet.SidechainDeposit{
		Txid:        send.Txid,
		WalletID:    walletID,
		Slot:        uint32(slot),
		Destination: destination,
		AmountSats:  amountSats,
		FeeSats:     feeSats,
	}); err != nil {
		h.svc.Log().Error().Err(fmt.Errorf("record the game deposit: %w", err)).Str("txid", send.Txid).Send()
	}
	return send.Txid, nil
}
